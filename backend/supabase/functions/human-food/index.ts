// Human Food API — Supabase Edge Function (Deno).
//
//   GET  /human-food/product?barcode=…   community-added product (not in Open Food Facts)
//   POST /human-food/verdict             cached-or-generated AI verdict for a barcode
//   POST /human-food/label               read packaging photos into a product (and store it)
//
// The Gemini key lives only here (secret GEMINI_API_KEY). Each verdict is generated
// once per (barcode, rubric version, language) and then served from Postgres to
// every user, so AI cost scales with the number of distinct products — not scans.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { clean, labelSchema, labelSystem, verdictSchema, verdictSystem } from "./prompts.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const VERDICT_MODEL = Deno.env.get("VERDICT_MODEL") ?? "gemini-3.5-flash-lite";
const LABEL_MODEL = Deno.env.get("LABEL_MODEL") ?? "gemini-3.5-flash";
const DAILY_AI_LIMIT = Number(Deno.env.get("DAILY_AI_LIMIT") ?? "2000");
// Per client (hashed IP) per hour. Only requests that would call the AI count.
const HOURLY_VERDICTS_PER_CLIENT = Number(Deno.env.get("HOURLY_VERDICTS_PER_CLIENT") ?? "60");
const HOURLY_LABELS_PER_CLIENT = Number(Deno.env.get("HOURLY_LABELS_PER_CLIENT") ?? "10");
const RATE_SALT = Deno.env.get("RATE_SALT") ?? Deno.env.get("SUPABASE_URL") ?? "human-food";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const BARCODE = /^\d{6,14}$/;
const LABEL_ID = /^label-[a-z0-9-]{4,40}$/i;

Deno.serve(async (req) => {
  const route = new URL(req.url).pathname.split("/").filter(Boolean).pop();
  try {
    if (req.method === "GET" && route === "product") return await getProduct(req);
    if (req.method === "POST" && route === "verdict") return await postVerdict(req);
    if (req.method === "POST" && route === "label") return await postLabel(req);
    return json({ error: "not_found" }, 404);
  } catch (err) {
    console.error(err);
    return json({ error: "server_error" }, 500);
  }
});

// ---------------------------------------------------------------------------

async function getProduct(req: Request): Promise<Response> {
  const barcode = new URL(req.url).searchParams.get("barcode") ?? "";
  if (!BARCODE.test(barcode) && !LABEL_ID.test(barcode)) return json({ error: "bad_barcode" }, 400);
  const { data } = await db.from("products").select("data").eq("barcode", barcode).maybeSingle();
  return data ? json({ product: data.data }) : json({ error: "not_found" }, 404);
}

async function postVerdict(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null);
  const barcode = String(body?.barcode ?? "");
  if (!BARCODE.test(barcode) && !LABEL_ID.test(barcode)) return json({ error: "bad_barcode" }, 400);

  const rubric = Math.trunc(Number(body?.rubricVersion));
  if (!(rubric >= 1 && rubric <= 1000)) return json({ error: "bad_rubric" }, 400);

  const language = String(body?.locale ?? "en").split(/[-_]/)[0].toLowerCase();
  const locale = /^[a-z]{2,3}$/.test(language) ? language : "en";

  const score = sanitizeScore(body?.score);
  if (!score) return json({ error: "bad_score" }, 400);
  // The cache key includes a hash of the score payload: a tampered score can only
  // create its own entry, never overwrite the one honest clients read.
  const payloadHash = await sha256(JSON.stringify(score));

  // 1. Shared cache hit — the common case, costs nothing.
  const cached = await db.from("verdicts").select("verdict")
    .eq("barcode", barcode).eq("rubric_version", rubric).eq("locale", locale).eq("payload_hash", payloadHash)
    .maybeSingle();
  if (cached.data) {
    db.rpc("bump_verdict_hits", { p_barcode: barcode, p_rubric: rubric, p_locale: locale, p_hash: payloadHash })
      .then(() => {});
    return json({ verdict: cached.data.verdict, cached: true });
  }

  // 2. Product facts come from trusted sources, never from the client.
  const product = await loadProduct(barcode);
  if (!product) return json({ error: "unknown_product" }, 404);

  if (!GEMINI_API_KEY) return json({ error: "ai_not_configured" }, 503);
  if (!(await withinClientLimit(req, "verdict", HOURLY_VERDICTS_PER_CLIENT))) return json({ error: "rate_limited" }, 429);
  if (!(await reserveAICall())) return json({ error: "daily_limit" }, 429);

  const input = `<product_data>\n${JSON.stringify({ product: product.summary, score })}\n</product_data>`;
  const raw = await gemini(VERDICT_MODEL, verdictSystem(locale), [{ text: input }], verdictSchema);
  const verdict = shapeVerdict(raw, product.brand);
  if (!verdict) return json({ error: "ai_bad_output" }, 502);

  await db.from("verdicts").upsert(
    { barcode, rubric_version: rubric, locale, payload_hash: payloadHash, verdict, score: score.value, model: VERDICT_MODEL },
    { onConflict: "barcode,rubric_version,locale,payload_hash", ignoreDuplicates: true },
  );
  return json({ verdict, cached: false });
}

async function postLabel(req: Request): Promise<Response> {
  const body = await req.json().catch(() => null);
  const images: unknown[] = Array.isArray(body?.images) ? body.images : [];
  if (images.length < 1 || images.length > 3) return json({ error: "bad_images" }, 400);
  if (!images.every((i) => typeof i === "string" && i.length < 3_500_000)) return json({ error: "bad_images" }, 400);

  const requested = body?.barcode ? String(body.barcode) : null;
  if (requested && !BARCODE.test(requested)) return json({ error: "bad_barcode" }, 400);

  if (requested) {
    // Already added by someone else? Serve that for consistency.
    const existing = await db.from("products").select("data").eq("barcode", requested).maybeSingle();
    if (existing.data) return json({ product: existing.data.data });
    // Never let a label read shadow a product that Open Food Facts already knows.
    if (await fetchOFF(requested)) return json({ error: "already_in_open_food_facts" }, 409);
  }

  if (!GEMINI_API_KEY) return json({ error: "ai_not_configured" }, 503);
  if (!(await withinClientLimit(req, "label", HOURLY_LABELS_PER_CLIENT))) return json({ error: "rate_limited" }, 429);
  if (!(await reserveAICall())) return json({ error: "daily_limit" }, 429);

  const parts = [
    ...(images as string[]).map((data) => ({ inline_data: { mime_type: "image/jpeg", data } })),
    { text: "Transcribe this product's packaging." },
  ];
  const raw = await gemini(LABEL_MODEL, labelSystem, parts, labelSchema);
  if (!raw || typeof raw.name !== "string" || !raw.name.trim()) return json({ error: "unreadable" }, 422);

  const barcode = requested ?? `label-${crypto.randomUUID().slice(0, 18)}`;
  const product = {
    barcode,
    name: raw.name.trim().slice(0, 140),
    brand: typeof raw.brand === "string" ? raw.brand.slice(0, 80) : null,
    imageURL: null,
    quantity: typeof raw.quantity === "string" ? raw.quantity.slice(0, 40) : null,
    ingredientsText: typeof raw.ingredientsText === "string" ? raw.ingredientsText.slice(0, 3000) : null,
    ingredients: strArray(raw.ingredients, 80).map((s) => s.toLowerCase()),
    nutrients: shapeNutrients(raw.nutrients),
    novaGroup: [1, 2, 3, 4].includes(raw.novaGroup) ? raw.novaGroup : null,
    additives: strArray(raw.additives, 40).map((s) => s.toLowerCase()).filter((s) => /^e\d{3,4}[a-z]*$/.test(s)),
    categories: strArray(raw.categories, 20),
    allergens: strArray(raw.allergens, 20),
    labels: [],
    fruitsVegNutsPercent: null,
    isBeverage: raw.isBeverage === true,
    source: "community",
  };

  await db.from("products").upsert({ barcode, data: product, source: "community" },
    { onConflict: "barcode", ignoreDuplicates: true });
  return json({ product });
}

// ---------------------------------------------------------------------------

type LoadedProduct = { summary: Record<string, unknown>; brand: string | null };

// Open Food Facts first (curated, and what the app itself shows); community reads
// are only a fallback for products OFF doesn't have.
async function loadProduct(barcode: string): Promise<LoadedProduct | null> {
  if (BARCODE.test(barcode)) {
    const off = await fetchOFF(barcode);
    if (off) return off;
  }
  const community = await db.from("products").select("data").eq("barcode", barcode).maybeSingle();
  if (community.data) {
    const p = community.data.data;
    return {
      brand: p.brand ?? null,
      summary: {
        name: p.name, quantity: p.quantity, isBeverage: p.isBeverage, novaGroup: p.novaGroup,
        categories: p.categories, ingredients: p.ingredientsText ?? (p.ingredients ?? []).join(", "),
        additives: p.additives, nutrientsPer100: p.nutrients,
      },
    };
  }
  return null;
}

async function fetchOFF(barcode: string): Promise<LoadedProduct | null> {
  const fields = "product_name,brands,quantity,categories_tags,nova_group,ingredients_text,additives_tags,labels_tags,nutriments";
  const res = await fetch(`https://world.openfoodfacts.org/api/v2/product/${barcode}.json?fields=${fields}`, {
    headers: { "User-Agent": "HumanFood-Backend/1.0" },
    signal: AbortSignal.timeout(8000),
  }).catch(() => null);
  if (!res?.ok) return null;
  const body = await res.json().catch(() => null); // OFF serves an HTML page during outages
  if (body?.status !== 1 || !body.product?.product_name) return null;
  const p = body.product;
  const n = p.nutriments ?? {};
  const pick = (k: string) => (typeof n[k] === "number" ? Math.round(n[k] * 10) / 10 : undefined);
  return {
    brand: p.brands ?? null,
    summary: {
      name: p.product_name,
      quantity: p.quantity,
      novaGroup: p.nova_group,
      categories: (p.categories_tags ?? []).slice(-6),
      ingredients: String(p.ingredients_text ?? "").slice(0, 1500),
      additives: p.additives_tags ?? [],
      labels: (p.labels_tags ?? []).slice(0, 8),
      nutrientsPer100: {
        energyKcal: pick("energy-kcal_100g"), fat: pick("fat_100g"), saturatedFat: pick("saturated-fat_100g"),
        sugars: pick("sugars_100g"), fiber: pick("fiber_100g"), protein: pick("proteins_100g"), salt: pick("salt_100g"),
      },
    },
  };
}

function sanitizeScore(s: any) {
  const value = Math.trunc(Number(s?.value));
  if (!(value >= 0 && value <= 100)) return null;
  const factors = (Array.isArray(s?.factors) ? s.factors : []).slice(0, 40).map((f: any) => ({
    title: String(f?.title ?? "").slice(0, 80),
    detail: String(f?.detail ?? "").slice(0, 240),
    impact: Math.max(-50, Math.min(50, Math.trunc(Number(f?.impact) || 0))),
  }));
  return { value, tier: String(s?.tier ?? "").slice(0, 20), factors };
}

function shapeVerdict(raw: any, brand: string | null) {
  if (!raw || typeof raw.headline !== "string" || typeof raw.summary !== "string") return null;
  const c = (s: unknown, max: number) => clean(String(s ?? ""), brand).slice(0, max);
  return {
    headline: c(raw.headline, 80),
    summary: c(raw.summary, 600),
    highlights: strArray(raw.highlights, 3).map((s) => c(s, 120)),
    considerations: strArray(raw.considerations, 3).map((s) => c(s, 120)),
    alternatives: (Array.isArray(raw.alternatives) ? raw.alternatives : []).slice(0, 3)
      .filter((a: any) => typeof a?.title === "string")
      .map((a: any) => ({ title: c(a.title, 70), reason: c(a.reason, 140) })),
    tip: typeof raw.tip === "string" ? c(raw.tip, 160) : null,
  };
}

function shapeNutrients(n: any) {
  const keys = ["energyKcal", "fat", "saturatedFat", "transFat", "carbohydrates", "sugars", "addedSugars", "fiber", "protein", "salt"];
  const out: Record<string, number | null> = {};
  for (const k of keys) {
    const v = Number(n?.[k]);
    out[k] = n?.[k] != null && Number.isFinite(v) && v >= 0 && v <= 1000 ? v : null;
  }
  return out;
}

function strArray(v: unknown, max: number): string[] {
  return (Array.isArray(v) ? v : []).filter((s) => typeof s === "string" && s.trim()).slice(0, max).map((s) => s.trim());
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Buckets by a salted hash of the caller's IP — the raw IP is never stored.
async function withinClientLimit(req: Request, kind: string, limit: number): Promise<boolean> {
  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
  const bucket = `${kind}:${(await sha256(RATE_SALT + ip)).slice(0, 32)}`;
  const { data, error } = await db.rpc("hit_rate_limit", { p_bucket: bucket, p_limit: limit, p_window_seconds: 3600 });
  if (error) console.error(error);
  return data === true;
}

async function reserveAICall(): Promise<boolean> {
  const { data, error } = await db.rpc("reserve_ai_call", { daily_limit: DAILY_AI_LIMIT });
  if (error) console.error(error);
  return data === true;
}

async function gemini(model: string, system: string, parts: unknown[], schema: unknown): Promise<any> {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-goog-api-key": GEMINI_API_KEY },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts }],
      generationConfig: { responseMimeType: "application/json", responseSchema: schema, temperature: 0.4 },
    }),
  });
  if (!res.ok) {
    console.error("gemini", res.status, await res.text());
    return null;
  }
  const body = await res.json();
  const text = body?.candidates?.[0]?.content?.parts?.find((p: any) => typeof p.text === "string")?.text;
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { "Content-Type": "application/json" } });
}
