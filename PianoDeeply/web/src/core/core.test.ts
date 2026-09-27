// Mirrors PianoCore's XCTest suite so the web and iOS apps behave the same.
import { describe, expect, it } from "vitest";
import {
  Clock, DayPhrase, addDays, greeting, isLongGap, latestPair, nextUpcomingRetest, pairsForTask, planTemplate, presetMinutes,
  retestDue, suggest, tempoChange, type EvidencePoint, type TaskSnapshot,
} from "./logic";
import { chordName, chordSpoken, chordTones, keyboardRange, keys, noteName, note, smoothTwoFiveOne, twoFiveOne, voicing } from "./chords";
import { feedbackAfter } from "./vocab";

const now = new Date(2026, 8, 27, 10).getTime(); // local time, like the app
const daysAgo = (n: number, hour = 10) => { const d = new Date(addDays(now, -n)); d.setHours(hour, 0, 0, 0); return d.getTime(); };
const task = (p: Partial<TaskSnapshot>): TaskSnapshot => ({
  id: crypto.randomUUID(), title: "T", skillName: null, skillIsBottleneck: false, createdAt: daysAgo(40),
  lastAttemptAt: null, lastColdAttemptAt: null, nextStep: null, isArchived: false, ...p,
});

describe("clock", () => {
  const t0 = 1_700_000_000_000;
  it("counts only running stretches and survives storage", () => {
    let c = Clock.started(t0);
    c = Clock.pause(c, t0 + 120_000);
    c = Clock.resume(c, t0 + 600_000);
    c = Clock.pause(c, t0 + 780_000);
    c = Clock.resume(c, t0 + 800_000);
    const stored = JSON.parse(JSON.stringify(c));
    expect(Clock.elapsed(stored, t0 + 860_000)).toBe(120_000 + 180_000 + 60_000);
  });
  it("paused clocks don't grow, and double pause/resume is harmless", () => {
    let c = Clock.pause(Clock.started(t0), t0 + 30_000);
    c = Clock.pause(c, t0 + 500_000);
    expect(Clock.elapsed(c, t0 + 3_600_000)).toBe(30_000);
    c = Clock.resume(c, t0 + 1_000_000);
    c = Clock.resume(c, t0 + 1_500_000);
    expect(Clock.elapsed(c, t0 + 1_600_000)).toBe(630_000);
  });
  it("never subtracts when the device clock moves backwards", () => {
    expect(Clock.elapsed({ accumulated: 300_000, runningSince: t0 }, t0 - 120_000)).toBe(300_000);
  });
  it("formats", () => {
    expect(Clock.format(0)).toBe("0:00");
    expect(Clock.format(724_000)).toBe("12:04");
    expect(Clock.format(3_729_000)).toBe("1:02:09");
  });
  it("retests are due at the start of a day", () => {
    const due = new Date(retestDue(new Date(2026, 2, 28, 23, 30).getTime(), 1));
    expect([due.getDate(), due.getHours(), due.getMinutes()]).toEqual([29, 0, 0]);
  });
});

describe("planner", () => {
  it("presets and custom lengths add up exactly, with a focus step and no empty steps", () => {
    for (const m of [...presetMinutes, 5, 7, 9, 10, 11, 25, 33, 45, 47, 75, 120, 240]) {
      const plan = planTemplate(m);
      expect(plan.reduce((n, p) => n + p.minutes, 0)).toBe(m);
      expect(plan.every((p) => p.minutes >= 1)).toBe(true);
      expect(plan.some((p) => p.kind === "focus")).toBe(true);
    }
    expect(planTemplate(20).map((p) => p.kind)).toEqual(["arrival", "reading", "focus", "application", "closing"]);
    expect(planTemplate(0).reduce((n, p) => n + p.minutes, 0)).toBe(5);
  });
});

describe("suggestions", () => {
  it("nothing logged means no suggestion", () => {
    expect(suggest([], [], null, now)).toBeNull();
    expect(suggest([task({})], [], null, now)).toBeNull();
  });
  it("a due retest comes first and says when it was scheduled", () => {
    const t = task({ skillIsBottleneck: true, lastAttemptAt: daysAgo(1), nextStep: "x" });
    const s = suggest([t], [{ id: "r", taskId: t.id, taskTitle: "T", dueDate: daysAgo(0, 0), scheduledAt: daysAgo(3), isCompleted: false }], "Left-hand coordination", now);
    expect(s?.rule).toBe("retestDue");
    expect(s?.reason).toBe("You set up this cold retest 3 days ago.");
  });
  it("the bottleneck reason names the skill", () => {
    const linked = task({ title: "Alberti bass", skillIsBottleneck: true, lastAttemptAt: daysAgo(2) });
    const s = suggest([task({ lastAttemptAt: daysAgo(0), nextStep: "y" }), linked], [], "Left-hand coordination", now);
    expect(s?.taskId).toBe(linked.id);
    expect(s?.reason).toBe("Because you marked left-hand coordination as your bottleneck.");
    expect(suggest([], [], "ii–V–I", now)?.reason.startsWith("Because you marked ii–V–I as your bottleneck.")).toBe(true);
  });
  it("resurfaces the most recent next step, then falls back to stale cold checks", () => {
    const recent = task({ lastAttemptAt: daysAgo(2), lastColdAttemptAt: daysAgo(2), nextStep: "  Try the turn at 66  " });
    expect(suggest([task({ lastAttemptAt: daysAgo(9), nextStep: "old" }), recent], [], null, now)?.reason)
      .toBe("You left yourself a next step 2 days ago: “Try the turn at 66”");
    const stale = task({ lastAttemptAt: daysAgo(30), lastColdAttemptAt: daysAgo(45), nextStep: "Slower" });
    expect(suggest([stale], [], null, now)?.reason).toBe("You haven't tried this cold since 6 weeks ago.");
    expect(suggest([task({ lastAttemptAt: daysAgo(25) })], [], null, now)?.reason).toBe("You've practised this but haven't tried it cold yet.");
  });
  it("previews only future, open retests", () => {
    const r = { id: "a", taskId: "t", taskTitle: "T", dueDate: addDays(now, 2), scheduledAt: daysAgo(1), isCompleted: false };
    expect(nextUpcomingRetest([r, { ...r, id: "b", dueDate: daysAgo(1) }, { ...r, id: "c", isCompleted: true }], now)?.id).toBe("a");
  });
  it("day phrases", () => {
    expect(DayPhrase.since(daysAgo(1), now)).toBe("yesterday");
    expect(DayPhrase.since(daysAgo(28), now)).toBe("4 weeks ago");
    expect(DayPhrase.until(addDays(now, 1), now)).toBe("tomorrow");
  });
});

describe("evidence", () => {
  const A = "task-a", B = "task-b";
  const p = (taskId: string, day: number, phase: EvidencePoint["phase"], tempo: number | null = null, nextStep = ""): EvidencePoint =>
    ({ id: crypto.randomUUID(), taskId, date: daysAgo(30 - day), phase, tempo, observation: "", nextStep });
  it("never pairs cold with after-practice, different tasks, or the same day", () => {
    expect(latestPair([p(A, 0, "cold", 60), p(A, 3, "afterPractice", 80), p(B, 5, "cold", 90)])).toBeNull();
    const sameDay = [p(A, 1, "cold"), { ...p(A, 1, "cold"), date: daysAgo(29, 11) }];
    expect(latestPair(sameDay)).toBeNull();
  });
  it("pairs earliest with latest in one phase, with tempo only when both were entered", () => {
    const pair = latestPair([p(A, 14, "cold", 72, "Try 76"), p(A, 15, "afterPractice", 100), p(A, 0, "cold", 60), p(A, 7, "cold", 66)]);
    expect(pair?.phase).toBe("cold");
    expect(pair && tempoChange(pair)).toBe(12);
    expect(pair?.next).toBe("Try 76");
    expect(tempoChange(pairsForTask(A, [p(A, 0, "cold"), p(A, 4, "cold", 80)])[0])).toBeNull();
  });
});

describe("chords", () => {
  it("spells ii–V–I correctly", () => {
    expect(twoFiveOne(note(3)).map(chordName)).toEqual(["Gm7", "C7", "Fmaj7"]);
    expect(twoFiveOne(note(3)).map((c) => chordTones(c).map(noteName))).toEqual([["G", "B♭", "D", "F"], ["C", "E", "G", "B♭"], ["F", "A", "C", "E"]]);
    expect(twoFiveOne(note(4)).map((c) => chordTones(c).map(noteName))).toEqual([["A", "C", "E", "G"], ["D", "F♯", "A", "C"], ["G", "B", "D", "F♯"]]);
    expect(twoFiveOne(note(3)).map(chordSpoken)).toEqual(["G minor seven", "C seven", "F major seven"]);
  });
  it("voices the expected keys", () => {
    const [ii, V, I] = twoFiveOne(note(3));
    expect(voicing(ii, 0).map((n) => n.midi)).toEqual([55, 58, 62, 65]);
    expect(voicing(V, 2).map((n) => n.midi)).toEqual([55, 58, 60, 64]);
    expect(voicing(I, 3).map((n) => n.midi)).toEqual([64, 65, 69, 72]);
  });
  it("every inversion fits the keyboard and smooth voice leading moves at most a step, in every key", () => {
    for (const k of keys) {
      const chords = twoFiveOne(k);
      for (const c of chords) for (let i = 0; i < 4; i++) {
        expect(voicing(c, i).every((n) => n.midi >= keyboardRange[0] && n.midi <= keyboardRange[1])).toBe(true);
      }
      const v = chords.map((c, i) => voicing(c, smoothTwoFiveOne[i]).map((n) => n.midi));
      for (let i = 0; i < 2; i++) expect(v[i].every((m, j) => Math.abs(m - v[i + 1][j]) <= 2)).toBe(true);
    }
  });
});

describe("feedback and greeting", () => {
  it("only an experiment that worked celebrates, quoting the user's own tempo", () => {
    expect(feedbackAfter("worked", 72, "afterPractice")).toEqual({ message: "Even at 72 bpm. Try it cold next time.", celebrate: true });
    expect(feedbackAfter("partly", 72, "afterPractice").celebrate).toBe(false);
    expect(feedbackAfter("worked", null, "afterPractice").message).not.toContain("bpm");
  });
  it("two weeks away is welcomed without counting", () => {
    expect(greeting(daysAgo(14), now)).toBe("Welcome back.");
    expect(isLongGap(null, now)).toBe(false);
    expect(greeting(daysAgo(1), now)).toBe("Good morning.");
  });
});
