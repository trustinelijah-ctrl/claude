import type { Config, Context } from "@netlify/functions";
import { GoogleGenAI } from "@google/genai";

/*
 * LOGOS reviewer. The web app and the iOS app both POST {prompt} here and
 * expect {text} back. Gemini is reached through Netlify's AI Gateway, which
 * injects the credentials at runtime — no key lives in this repo or in
 * either client. Callers treat any non-2xx as "reviewer unavailable" and
 * keep working, so failures here are never fatal to the app.
 */
const MAX_PROMPT = 8000;

export default async (req: Request, _context: Context) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  let prompt = "";
  try {
    const body = await req.json();
    prompt = typeof body?.prompt === "string" ? body.prompt.trim() : "";
  } catch {
    return Response.json({ error: "bad-json" }, { status: 400 });
  }
  if (!prompt) return Response.json({ error: "empty" }, { status: 400 });
  if (prompt.length > MAX_PROMPT) return Response.json({ error: "too-long" }, { status: 413 });

  try {
    const ai = new GoogleGenAI({});
    const res = await ai.models.generateContent({
      model: Netlify.env.get("LOGOS_AI_MODEL") || "gemini-2.5-flash",
      contents: prompt,
      config: { temperature: 0.4, maxOutputTokens: 700 },
    });
    const text = (res.text || "").trim();
    if (!text) return Response.json({ error: "empty-reply" }, { status: 502 });
    return Response.json({ text });
  } catch (err) {
    console.error("ai: upstream failure", err);
    return Response.json({ error: "upstream" }, { status: 502 });
  }
};

export const config: Config = {
  rateLimit: { windowLimit: 30, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
