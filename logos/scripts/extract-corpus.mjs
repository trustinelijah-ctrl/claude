// Evaluates the web app's script in a sandbox and writes its content corpus
// to content/corpus.json, the single source the iOS app bundles.
// Run: node scripts/extract-corpus.mjs
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(root, "web/index.html"), "utf8");
// The app is the largest inline <script>; later small scripts are add-ons.
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
if (!scripts.length) throw new Error("app script not found");
let src = scripts.reduce((a, b) => (b.length > a.length ? b : a)).replace(/\bboot\(\);\s*$/, "");

const KEYS = ["SCRIPTURE","PASSAGES","MASTERY","CONCEPTS","MEMORY_SEED","RHETORIC","RH_FOLLOW",
  "SPEECH","SPEECH_CATS","SOURCES","SOURCE_CATS","CAPTURE_SEED","KINDS","ARGUMENTS",
  "WHO","DIFF","EVENING_Q","LESSONS","TRANSLATIONS","PLANS","PATH","VOICES",
  "VOICE_KIND","FIGURES","MODES","MODE_TIER","DEPTH","DEEPEN","THINK","QWHY",
  "MODULES","BUILDS","PLAN_Q","PLAN_DEPTH","PLAN_THINK","SAIDW","PQWHY",
  "PLATES","LESSON_IDS"];
src += "\n;globalThis.__OUT = {" + KEYS.map(k => `${k}: typeof ${k} === "undefined" ? null : ${k}`).join(",") + "};";

const noop = () => {};
const el = new Proxy(function(){}, { get: (t, k) => k === Symbol.toPrimitive ? () => "" : el, apply: () => el, construct: () => el });
const ctx = { console, setTimeout: noop, clearTimeout: noop, setInterval: noop, clearInterval: noop,
  document: el, window: {}, navigator: {}, localStorage: undefined, matchMedia: () => ({ matches: false }) };
ctx.window = ctx; ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(src, ctx, { filename: "logos.js" });

const out = JSON.parse(JSON.stringify(ctx.__OUT)); // drops functions
const missing = KEYS.filter(k => out[k] == null);
if (missing.length) console.warn("missing:", missing.join(", "));
const body = JSON.stringify(out);
const version = crypto.createHash("sha256").update(body).digest("hex").slice(0, 12);
const corpus = JSON.stringify({ app: "logos", schema: 1, version, ...out });
// Default: content/corpus.json (bundled into the iOS app). Extra targets via
// --out <file>, e.g. the Netlify build publishes web/corpus.json so installed
// apps can pick up new content without an App Store release.
const targets = [path.join(root, "content/corpus.json")];
process.argv.forEach((a, i) => { if (a === "--out" && process.argv[i + 1]) targets.push(path.resolve(root, process.argv[i + 1])); });
for (const t of targets) fs.writeFileSync(t, corpus);
fs.writeFileSync(path.join(root, "content/corpus.version"), version + "\n");
const dest = targets.join(", ");
for (const k of KEYS) {
  const v = out[k]; const n = Array.isArray(v) ? v.length : v && typeof v === "object" ? Object.keys(v).length : 0;
  console.log(k.padEnd(14), n);
}
console.log("version", version, "wrote", dest, (corpus.length / 1024).toFixed(0) + " KB");
