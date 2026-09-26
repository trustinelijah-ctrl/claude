import type { Config, Context } from "@netlify/functions";
import { getDeployStore, getStore } from "@netlify/blobs";
import { createHash, timingSafeEqual } from "node:crypto";

/*
 * Encrypted sync between the web app and the iOS app.
 *
 * Clients derive three values from a 20-character code only the learner holds:
 *   id   = SHA-256("logos-sync-id:"   + code)  the blob's name
 *   auth = SHA-256("logos-sync-auth:" + code)  sent on every request
 *   key  = SHA-256("logos-sync-key:"  + code)  AES-256-GCM key, never sent
 * The server keeps only the ciphertext and a hash of `auth`, so it can check
 * that a caller holds the code without being able to decrypt anything.
 *
 *   GET /api/sync/<id>                 -> {updated, blob} | 404
 *   PUT /api/sync/<id>  {updated,blob} -> {ok, updated}
 */
const MAX_BLOB = 4 * 1024 * 1024;
const HEX64 = /^[0-9a-f]{64}$/;

function store() {
  // Deploy previews and branch deploys never touch production data.
  return Netlify.context?.deploy?.context === "production"
    ? getStore({ name: "logos-sync", consistency: "strong" })
    : getDeployStore("logos-sync");
}

const sha256 = (s: string) => createHash("sha256").update(s).digest("hex");
function same(a: string, b: string) {
  return a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b));
}

type Record = { updated: number; blob: string; authHash: string };

export default async (req: Request, context: Context) => {
  const id = String(context.params?.id || "");
  const auth = req.headers.get("x-sync-auth") || "";
  if (!HEX64.test(id) || !HEX64.test(auth)) return Response.json({ error: "bad-request" }, { status: 400 });
  const headers = { "Cache-Control": "no-store" };
  const blobs = store();
  const rec = (await blobs.get(id, { type: "json" })) as Record | null;
  const authHash = sha256(auth);
  // A wrong code looks exactly like no data.
  const owner = !!rec && same(rec.authHash, authHash);

  if (req.method === "GET") {
    if (!owner) return Response.json({ error: "not-found" }, { status: 404, headers });
    return Response.json({ updated: rec!.updated, blob: rec!.blob }, { headers });
  }

  if (req.method === "PUT") {
    if (rec && !owner) return Response.json({ error: "forbidden" }, { status: 403, headers });
    let body: { updated?: unknown; blob?: unknown };
    try { body = await req.json(); } catch { return Response.json({ error: "bad-json" }, { status: 400 }); }
    const updated = Number(body.updated);
    const blob = body.blob;
    if (!Number.isFinite(updated) || updated <= 0) return Response.json({ error: "bad-updated" }, { status: 400 });
    if (typeof blob !== "string" || !/^[A-Za-z0-9+/=]+$/.test(blob)) return Response.json({ error: "bad-blob" }, { status: 400 });
    if (blob.length > MAX_BLOB) return Response.json({ error: "too-large" }, { status: 413 });
    await blobs.setJSON(id, { updated, blob, authHash } satisfies Record);
    return Response.json({ ok: true, updated }, { headers });
  }

  return new Response("Method Not Allowed", { status: 405 });
};

export const config: Config = {
  path: "/api/sync/:id",
  rateLimit: { windowLimit: 30, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
