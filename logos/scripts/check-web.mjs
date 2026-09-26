// Static checks for the deployable web folder (runs in CI without a browser):
// the app script evaluates, the add-on hooks exist, every referenced file is
// present, the manifest is valid and sync.js round-trips with WebCrypto.
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const web = (p) => path.join(root, "web", p);
const html = fs.readFileSync(web("index.html"), "utf8");
let failures = 0;
const ok = (cond, msg) => { console.log((cond ? "ok   " : "FAIL ") + msg); if (!cond) failures++; };

const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
ok(scripts.length >= 2, "app script and add-on script present");
for (const [i, s] of scripts.entries()) {
  try { new vm.Script(s, { filename: `inline-${i}.js` }); ok(true, `inline script ${i} parses`); }
  catch (e) { ok(false, `inline script ${i} parses: ${e.message}`); }
}
for (const ref of [...html.matchAll(/(?:href|src)="(\/[^"]+)"/g)].map((m) => m[1])) {
  ok(fs.existsSync(web(ref.slice(1))), `referenced file exists: ${ref}`);
}
const manifest = JSON.parse(fs.readFileSync(web("manifest.webmanifest"), "utf8"));
ok(manifest.start_url === "/" && manifest.display === "standalone", "manifest is installable");
for (const icon of manifest.icons) ok(fs.existsSync(web(icon.src.slice(1))), `manifest icon exists: ${icon.src}`);
try { new vm.Script(fs.readFileSync(web("sw.js"), "utf8")); ok(true, "sw.js parses"); } catch (e) { ok(false, "sw.js parses: " + e.message); }

const ctx = { crypto: globalThis.crypto, TextEncoder, TextDecoder, btoa, atob };
ctx.globalThis = ctx; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(web("sync.js"), "utf8"), ctx);
const S = ctx.LogosSync;
const code = S.generate();
ok(S.normalize(S.display(code).toLowerCase()) === code, "sync code normalises");
ok(S.normalize("short") === null, "short code rejected");
const blob = await S.seal(code, "Grüße ✓");
ok((await S.open(code, blob)) === "Grüße ✓", "sync.js seal/open round trip");
let wrong = false; try { await S.open(S.generate(), blob); } catch { wrong = true; }
ok(wrong, "wrong code cannot open");
ok(S.decide(5, null, 0) === "push" && S.decide(5, 9, 5) === "pull" && S.decide(9, 8, 5) === "conflict", "sync plan matches iOS");

if (failures) { console.error(`${failures} check(s) failed`); process.exit(1); }
console.log("web checks passed");
