import type { Config, Context } from "@netlify/functions";
import { getDeployStore, getStore } from "@netlify/blobs";

/*
 * Cross-device sync between the web app and the iOS app.
 *
 * The server never sees learner data in the clear. Each client derives two
 * values from a random sync code the learner holds:
 *   id  = SHA-256("logos-sync-id:"  + code)  -> the blob key (64 hex chars)
 *   key = SHA-256("logos-sync-key:" + code)  -> an AES-256-GCM key, client-side only
 * and uploads only base64(nonce || ciphertext || tag). Knowing the id lets you
 * read or overwrite the ciphertext, not decrypt it.
 *
 *   GET  /api/sync/<id>                 -> {updated, blob} | 404
 *   PUT  /api/sync/<id>  {updated,blob} -> {ok, updated}
 */
const MAX_BLOB = 4 * 1024 * 1024;
const ID_RE = /^[0-9a-f]{64}$/;

function store() {
  // Keep deploy previews and branch deploys out of the production store.
  return Netlify.context?.deploy?.context === "production"
    ? getStore({ name: "logos-sync", consistency: "strong" })
    : getDeployStore("logos-sync");
}

export default async (req: Request, context: Context) => {
  const id = String(context.params?.id || "");
  if (!ID_RE.test(id)) return Response.json({ error: "bad-id" }, { status: 400 });
  const headers = { "Cache-Control": "no-store" };

  if (req.method === "GET") {
    const rec = await store().get(id, { type: "json" });
    if (!rec) return Response.json({ error: "not-found" }, { status: 404, headers });
    return Response.json(rec, { headers });
  }

  if (req.method === "PUT") {
    let body: { updated?: unknown; blob?: unknown };
    try { body = await req.json(); } catch { return Response.json({ error: "bad-json" }, { status: 400 }); }
    const updated = Number(body.updated);
    const blob = body.blob;
    if (!Number.isFinite(updated) || updated <= 0) return Response.json({ error: "bad-updated" }, { status: 400 });
    if (typeof blob !== "string" || !/^[A-Za-z0-9+/=]+$/.test(blob)) return Response.json({ error: "bad-blob" }, { status: 400 });
    if (blob.length > MAX_BLOB) return Response.json({ error: "too-large" }, { status: 413 });
    await store().setJSON(id, { updated, blob, v: 1 });
    return Response.json({ ok: true, updated }, { headers });
  }

  if (req.method === "DELETE") {
    await store().delete(id);
    return Response.json({ ok: true }, { headers });
  }

  return new Response("Method Not Allowed", { status: 405 });
};

export const config: Config = {
  path: "/api/sync/:id",
  rateLimit: { windowLimit: 60, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
