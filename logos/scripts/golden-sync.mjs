// Seals a payload with web/sync.js (WebCrypto) so the Swift tests can prove
// the iOS implementation opens it, and records the derived id.
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ctx = { crypto: globalThis.crypto, TextEncoder, TextDecoder, btoa, atob, console };
ctx.globalThis = ctx; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(root, "web/sync.js"), "utf8"), ctx);
const S = ctx.LogosSync;
const code = S.normalize("ABCD-EFGH-JKLM-NPQR-STUV");
const text = JSON.stringify({ app: "logos", version: 2, data: { v: 2, lang: "de", note: "Grüße — ✓" } });
const blob = await S.seal(code, text);
const { id, auth } = await S.derive(code);
if (await S.open(code, blob) !== text) throw new Error("round trip failed");
fs.writeFileSync(path.join(root, "ios/Tests/LogosCoreTests/golden-sync.json"), JSON.stringify({ code, id, auth, blob, text }));
console.log("golden sync id", id.slice(0, 12) + "…");
// And the reverse: open a blob the Swift test sealed, if present.
const back = path.join(root, "ios/Tests/LogosCoreTests/.swift-sealed.json");
if (fs.existsSync(back)) {
  const j = JSON.parse(fs.readFileSync(back, "utf8"));
  console.log("opened Swift-sealed blob:", await S.open(j.code, j.blob) === j.text ? "OK" : "MISMATCH");
}
