// Runs the web app's optOrder / gapsFor / similarity on real corpus text and
// writes the results as golden values for the Swift port's tests.
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const html = fs.readFileSync(path.join(root, "web/index.html"), "utf8");
const app = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).reduce((a, b) => (b.length > a.length ? b : a));
const src = app.replace(/\bboot\(\);\s*$/, "") +
  "\n;globalThis.__T = {optOrder, gapsFor, similarity, LESSONS, SCRIPTURE, PASSAGES, PLAN_Q};";
const noop = () => {};
const el = new Proxy(function(){}, { get: (t, k) => k === Symbol.toPrimitive ? () => "" : el, apply: () => el, construct: () => el });
const ctx = { console, setTimeout: noop, clearTimeout: noop, setInterval: noop, clearInterval: noop, document: el, navigator: {}, matchMedia: () => ({ matches: false }) };
ctx.window = ctx; vm.createContext(ctx); vm.runInContext(src, ctx);
const T = ctx.__T;

const opts = [];
for (const l of Object.values(T.LESSONS)) for (const q of l.check) opts.push({ q: q.q.en, n: q.opts.length, order: T.optOrder(q) });
for (const q of Object.values(T.PLAN_Q)) opts.push({ q: q.q.en, n: q.opts.length, order: T.optOrder(q) });

const texts = [...Object.entries(T.SCRIPTURE).map(([k, s]) => [k, s.en]), ...Object.entries(T.SCRIPTURE).slice(0, 20).map(([k, s]) => [k + "de", s.de]),
  ...Object.entries(T.PASSAGES).map(([k, p]) => [k, p.en])];
const gaps = [];
for (const [k, t] of texts) for (const stage of [1, 2, 3, 4]) gaps.push({ text: t, stage, seed: "u" + k, gaps: T.gapsFor(t, stage, "u" + k) });

const sims = [];
for (const [k, t] of texts.slice(0, 40)) {
  const w = t.split(/\s+/);
  for (const said of [t, w.slice(0, Math.ceil(w.length / 2)).join(" "), w.reverse().join(" "), "", t.toUpperCase()])
    sims.push({ said, text: t, score: T.similarity(said, t) });
}
fs.writeFileSync(path.join(root, "ios/Tests/LogosCoreTests/golden-text.json"), JSON.stringify({ opts, gaps, sims }));
console.log("golden:", opts.length, "orders,", gaps.length, "gap sets,", sims.length, "similarities");
