// Recording with the browser's MediaRecorder. Audio blobs are kept in
// IndexedDB on this device only; the JSON store holds their metadata.
import { useSyncExternalStore } from "react";
import { update, uid, type Recording } from "./store";

const DB_NAME = "piano-deeply-audio";
const STORE = "blobs";

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
async function tx<T>(mode: IDBTransactionMode, run: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const req = run(db.transaction(STORE, mode).objectStore(STORE));
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}
export const putBlob = (id: string, blob: Blob) => tx("readwrite", (s) => s.put(blob, id));
export const getBlob = (id: string) => tx<Blob | undefined>("readonly", (s) => s.get(id));
export const deleteBlob = (id: string) => tx("readwrite", (s) => s.delete(id)).catch(() => undefined);

/** Removes the audio and its record together. A missing blob isn't an error. */
export function deleteRecording(id: string) {
  update((d) => { d.recordings = d.recordings.filter((r) => r.id !== id); });
  void deleteBlob(id);
}

export async function downloadRecording(r: Recording) {
  const blob = await getBlob(r.id);
  if (!blob) return false;
  const ext = r.mimeType.includes("mp4") ? "m4a" : r.mimeType.includes("ogg") ? "ogg" : "webm";
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${r.title.replace(/[^\w\- ]+/g, "").trim() || "recording"}-${r.id.slice(0, 8)}.${ext}`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 10_000);
  return true;
}

// ---------- recorder ----------
export type Permission = "undetermined" | "granted" | "denied" | "unsupported";
interface RecorderState { permission: Permission; recording: boolean; ownerId: string | null; startedAt: number | null; error: string | null }

let state: RecorderState = {
  permission: typeof MediaRecorder === "undefined" || !navigator.mediaDevices ? "unsupported" : "undetermined",
  recording: false, ownerId: null, startedAt: null, error: null,
};
const listeners = new Set<() => void>();
const set = (patch: Partial<RecorderState>) => { state = { ...state, ...patch }; listeners.forEach((l) => l()); };
export const useRecorder = () =>
  useSyncExternalStore((l) => (listeners.add(l), () => listeners.delete(l)), () => state);

// Reflect a permission already granted or refused, without prompting.
navigator.permissions?.query({ name: "microphone" as PermissionName }).then((p) => {
  const map = (s: PermissionState): Permission => (s === "granted" ? "granted" : s === "denied" ? "denied" : "undetermined");
  if (state.permission !== "unsupported") set({ permission: map(p.state) });
  p.onchange = () => set({ permission: map(p.state) });
}).catch(() => undefined);

let media: MediaRecorder | null = null;
let chunks: Blob[] = [];
let onFinish: ((r: Recording) => void) | null = null;
let pendingTitle = "";
let links: Pick<Recording, "taskId" | "attemptId" | "sessionId"> = { taskId: null, attemptId: null, sessionId: null };

/** Asks for the microphone (only after the app has explained why) and starts. */
export async function startRecording(ownerId: string, title: string, link: Partial<typeof links>, finished?: (r: Recording) => void) {
  if (state.recording) return;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false } });
    const type = ["audio/mp4", "audio/webm;codecs=opus", "audio/webm"].find((t) => MediaRecorder.isTypeSupported?.(t));
    media = new MediaRecorder(stream, type ? { mimeType: type } : undefined);
    chunks = [];
    pendingTitle = title;
    links = { taskId: null, attemptId: null, sessionId: null, ...link };
    onFinish = finished ?? null;
    media.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
    media.start(1000);
    set({ permission: "granted", recording: true, ownerId, startedAt: Date.now(), error: null });
  } catch (e) {
    const denied = e instanceof DOMException && (e.name === "NotAllowedError" || e.name === "SecurityError");
    set(denied ? { permission: "denied" } : { error: "Recording couldn't start. Another app may be using the microphone." });
  }
}

/** Stops and saves the take, whoever calls it, so closing a screen never loses audio. */
export function stopRecording(): Promise<Recording | null> {
  const rec = media;
  if (!rec || !state.recording) return Promise.resolve(null);
  const started = state.startedAt ?? Date.now();
  const title = pendingTitle, link = links, done = onFinish;
  media = null; onFinish = null;
  set({ recording: false, ownerId: null, startedAt: null });
  return new Promise((resolve) => {
    rec.onstop = async () => {
      rec.stream.getTracks().forEach((t) => t.stop());
      const blob = new Blob(chunks, { type: rec.mimeType || "audio/webm" });
      const recording: Recording = { id: uid(), createdAt: started, duration: (Date.now() - started) / 1000, title, mimeType: blob.type, ...link };
      try { await putBlob(recording.id, blob); } catch { /* the record still says it existed */ }
      update((d) => { d.recordings.push(recording); });
      done?.(recording);
      resolve(recording);
    };
    rec.stop();
  });
}

export function stopIfOwnedBy(ownerId: string) {
  return state.recording && state.ownerId === ownerId ? stopRecording() : Promise.resolve(null);
}

// ---------- player ----------
interface PlayerState { playingId: string | null; missing: Set<string> }
let player: PlayerState = { playingId: null, missing: new Set() };
const playerListeners = new Set<() => void>();
const setPlayer = (p: Partial<PlayerState>) => { player = { ...player, ...p }; playerListeners.forEach((l) => l()); };
export const usePlayer = () =>
  useSyncExternalStore((l) => (playerListeners.add(l), () => playerListeners.delete(l)), () => player);

let audio: HTMLAudioElement | null = null;
export async function togglePlay(id: string) {
  if (player.playingId === id) { audio?.pause(); audio = null; setPlayer({ playingId: null }); return; }
  audio?.pause();
  const blob = await getBlob(id).catch(() => undefined);
  if (!blob) { setPlayer({ missing: new Set([...player.missing, id]), playingId: null }); return; }
  const el = new Audio(URL.createObjectURL(blob));
  audio = el;
  el.onended = () => { if (audio === el) { audio = null; setPlayer({ playingId: null }); } };
  el.play().then(() => setPlayer({ playingId: id })).catch(() => setPlayer({ missing: new Set([...player.missing, id]), playingId: null }));
}

// ---------- keep the screen awake during a session ----------
let lock: WakeLockSentinel | null = null;
let wanted = false;
export async function keepAwake(on: boolean) {
  wanted = on;
  if (!("wakeLock" in navigator)) return;
  if (on && !lock) lock = await navigator.wakeLock.request("screen").catch(() => null);
  if (!on && lock) { await lock.release().catch(() => undefined); lock = null; }
}
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && wanted) { lock = null; void keepAwake(true); }
});
