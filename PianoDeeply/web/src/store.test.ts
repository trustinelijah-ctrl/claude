// Delete rules and snapshots: the parts of the store that could quietly lose or misreport evidence.
import { beforeAll, describe, expect, it } from "vitest";

let store: typeof import("./store");
let exporter: typeof import("./exporter");

beforeAll(async () => {
  const mem = new Map<string, string>();
  Object.assign(globalThis, {
    window: { addEventListener: () => undefined },
    localStorage: { getItem: (k: string) => mem.get(k) ?? null, setItem: (k: string, v: string) => mem.set(k, v) },
  });
  store = await import("./store");
  exporter = await import("./exporter");
});

describe("store", () => {
  it("starts honest: starter subskills only, all Not explored", () => {
    const d = store.emptyDB();
    expect(d.tasks.length + d.attempts.length + d.sessions.length).toBe(0);
    expect(d.skills.length).toBeGreaterThan(20);
    expect(d.skills.every((s) => s.state === "notExplored" && !s.isBottleneck)).toBe(true);
  });

  it("deleting a target removes its attempts and retests but keeps recordings and sessions", () => {
    const d = store.emptyDB();
    const t = store.newTask("Scale");
    const a = store.newAttempt(t.id, "cold");
    const s = store.newSession("practice", [], t.id);
    a.sessionId = s.id;
    d.tasks.push(t); d.attempts.push(a); d.sessions.push(s);
    d.recordings.push({ id: "r", createdAt: 0, duration: 3, title: "Take", mimeType: "audio/webm", taskId: t.id, attemptId: a.id, sessionId: s.id });
    store.scheduleRetest(d, t.id, 1, "");
    store.deleteTask(d, t.id);
    expect(d.attempts).toHaveLength(0);
    expect(d.retests).toHaveLength(0);
    expect(d.recordings[0]).toMatchObject({ taskId: null, attemptId: null, sessionId: s.id });
    expect(d.sessions[0].focusTaskId).toBeNull();
  });

  it("deleting an attempt touches nothing else", () => {
    const d = store.emptyDB();
    const t = store.newTask("Bars 9–12");
    const first = store.newAttempt(t.id, "cold"), second = store.newAttempt(t.id, "afterPractice");
    d.tasks.push(t); d.attempts.push(first, second);
    store.deleteAttempt(d, first.id);
    expect(d.tasks).toHaveLength(1);
    expect(d.attempts.map((a) => a.id)).toEqual([second.id]);
  });

  it("a blank latest next step hides an older one", () => {
    const d = store.emptyDB();
    const t = store.newTask("Nocturne");
    d.tasks.push(t);
    d.attempts.push(store.newAttempt(t.id, "cold", { date: Date.now() - 60 * 86_400_000, nextStep: "Slower" }));
    const recent = store.newAttempt(t.id, "cold", { date: Date.now() - 86_400_000 });
    d.attempts.push(recent);
    expect(store.taskSnapshot(d, t).nextStep).toBeNull();
    recent.nextStep = "Turn at 66";
    expect(store.taskSnapshot(d, t).nextStep).toBe("Turn at 66");
  });

  it("one bottleneck at a time", () => {
    const d = store.emptyDB();
    const [a, b] = d.skills;
    store.toggleBottleneck(d, a.id);
    store.toggleBottleneck(d, b.id);
    expect(d.skills.filter((s) => s.isBottleneck).map((s) => s.id)).toEqual([b.id]);
    store.toggleBottleneck(d, b.id);
    expect(d.skills.some((s) => s.isBottleneck)).toBe(false);
  });

  it("the export reflects saved data in the iOS format", () => {
    const d = store.emptyDB();
    const t = store.newTask("ii–V–I in F");
    d.tasks.push(t);
    d.attempts.push(store.newAttempt(t.id, "cold", { tempo: 72, isRetest: true }));
    const bundle = exporter.makeBundle(d, Date.UTC(2026, 8, 27));
    expect(bundle.exportedAt).toBe("2026-09-27T00:00:00Z");
    expect(bundle.attempts[0]).toMatchObject({ phase: "coldRetest", tempo: 72, taskID: t.id });
    expect(bundle.tasks.map((x) => x.title)).toEqual(["ii–V–I in F"]);
  });
});
