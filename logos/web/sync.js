/* LOGOS sync, browser side. The iOS app implements the same scheme
   (ios/Logos/Core/Network.swift); a test seals here and opens there.

   A 20-character code is the only secret. From it:
     id   = hex SHA-256("logos-sync-id:"   + code)  the blob's name on the server
     auth = hex SHA-256("logos-sync-auth:" + code)  proves the caller holds the code
     key  = SHA-256("logos-sync-key:"  + code)      AES-256-GCM key, never sent
   The server stores base64(nonce || ciphertext || tag) and cannot read it. */
(function(root){
  "use strict";
  const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const enc = new TextEncoder(), dec = new TextDecoder();
  const subtle = () => (root.crypto || globalThis.crypto).subtle;

  function normalize(raw){
    const n = String(raw || "").toUpperCase().split("").filter(function(c){ return ALPHABET.indexOf(c) >= 0; }).join("");
    return n.length === 20 ? n : null;
  }
  function generate(){
    const b = new Uint8Array(20); (root.crypto || globalThis.crypto).getRandomValues(b);
    let s = ""; for(let i=0;i<20;i++) s += ALPHABET[b[i] % 32];
    return s;
  }
  function display(code){ return code.match(/.{4}/g).join("-"); }
  function hex(buf){ return Array.from(new Uint8Array(buf)).map(function(x){ return x.toString(16).padStart(2,"0"); }).join(""); }
  function b64(bytes){ let s = ""; bytes.forEach(function(x){ s += String.fromCharCode(x); }); return btoa(s); }
  function unb64(s){ const bin = atob(s); const out = new Uint8Array(bin.length); for(let i=0;i<bin.length;i++) out[i] = bin.charCodeAt(i); return out; }

  async function derive(code){
    const id = hex(await subtle().digest("SHA-256", enc.encode("logos-sync-id:" + code)));
    const auth = hex(await subtle().digest("SHA-256", enc.encode("logos-sync-auth:" + code)));
    const raw = await subtle().digest("SHA-256", enc.encode("logos-sync-key:" + code));
    const key = await subtle().importKey("raw", raw, {name:"AES-GCM"}, false, ["encrypt","decrypt"]);
    return {id:id, auth:auth, key:key};
  }
  async function seal(code, text){
    const k = await derive(code);
    const iv = (root.crypto || globalThis.crypto).getRandomValues(new Uint8Array(12));
    const ct = new Uint8Array(await subtle().encrypt({name:"AES-GCM", iv:iv}, k.key, enc.encode(text)));
    const out = new Uint8Array(12 + ct.length); out.set(iv, 0); out.set(ct, 12);
    return b64(out);
  }
  async function open(code, blob){
    const k = await derive(code);
    const all = unb64(blob);
    const pt = await subtle().decrypt({name:"AES-GCM", iv:all.slice(0,12)}, k.key, all.slice(12));
    return dec.decode(pt);
  }

  /* Talks to /api/sync/<id>. Returns {updated, data} | null (nothing stored). */
  async function pull(code){
    const k = await derive(code);
    const r = await fetch("/api/sync/" + k.id, {cache:"no-store", headers:{"X-Sync-Auth": k.auth}});
    if(r.status === 404) return null;
    if(!r.ok) throw new Error("server:" + r.status);
    const j = await r.json();
    let text;
    try{ text = await open(code, j.blob); }catch(e){ throw new Error("wrong-code"); }
    const payload = JSON.parse(text);
    if(!payload || payload.app !== "logos" || !payload.data) throw new Error("corrupt");
    return {updated: j.updated, data: payload.data};
  }
  async function push(code, data, updated){
    const k = await derive(code);
    const blob = await seal(code, JSON.stringify({app:"logos", version:2, data:data}));
    const r = await fetch("/api/sync/" + k.id, {method:"PUT", headers:{"Content-Type":"application/json", "X-Sync-Auth": k.auth},
      body: JSON.stringify({updated:updated, blob:blob})});
    if(!r.ok) throw new Error("server:" + r.status);
  }
  /* Same rule as SyncPlan.decide on iOS. */
  function decide(local, remote, lastSync){
    if(remote === null || remote === undefined) return "push";
    const l = local > lastSync, r = remote > lastSync;
    if(!l && !r) return "upToDate";
    if(l && !r) return "push";
    if(!l && r) return "pull";
    return "conflict";
  }
  root.LogosSync = {normalize:normalize, generate:generate, display:display, derive:derive,
                    seal:seal, open:open, pull:pull, push:push, decide:decide};
})(typeof window !== "undefined" ? window : globalThis);
