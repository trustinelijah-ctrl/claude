// Port of PianoCore's SessionPlanner, SessionClock, RetestInterval,
// SuggestionEngine, DayPhrase, EvidenceComparison and ReturnGreeting.
// Times are milliseconds since the epoch; "days" follow the local calendar.
import type { AttemptPhase, StepKind } from "./vocab";

export const isBlank = (s: string | null | undefined) => !s || s.trim() === "";

// ---------- calendar ----------
export const DAY = 86_400_000;
export function startOfDay(t: number): number {
  const d = new Date(t);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}
export function addDays(t: number, days: number): number {
  const d = new Date(t);
  d.setDate(d.getDate() + days);
  return d.getTime();
}
/** Whole calendar days from a to b (DST-safe). */
export function daysBetween(a: number, b: number): number {
  return Math.round((startOfDay(b) - startOfDay(a)) / DAY);
}
export const sameDay = (a: number, b: number) => daysBetween(a, b) === 0;

export const DayPhrase = {
  since(t: number, now: number): string {
    const days = daysBetween(t, now);
    if (days < 1) return "today";
    if (days === 1) return "yesterday";
    if (days < 14) return `${days} days ago`;
    return `${Math.floor(days / 7)} weeks ago`;
  },
  until(t: number, now: number): string {
    const days = daysBetween(now, t);
    if (days < 1) return "today";
    if (days === 1) return "tomorrow";
    if (days < 14) return `in ${days} days`;
    return `in ${Math.floor(days / 7)} weeks`;
  },
};

// ---------- planner ----------
export interface PlannedStep { kind: StepKind; minutes: number }
export const presetMinutes = [20, 30, 60, 90];
export const minimumMinutes = 5;
export const maximumMinutes = 240;

const presets: Record<number, PlannedStep[]> = {
  20: [["arrival", 3], ["reading", 4], ["focus", 8], ["application", 4], ["closing", 1]].map(s),
  30: [["arrival", 4], ["reading", 5], ["focus", 13], ["application", 6], ["closing", 2]].map(s),
  60: [["arrival", 5], ["technique", 8], ["reading", 8], ["focus", 20], ["application", 10], ["ear", 6], ["closing", 3]].map(s),
  90: [["arrival", 6], ["technique", 10], ["reading", 10], ["focus", 25], ["application", 15], ["ear", 8], ["improvisation", 12], ["closing", 4]].map(s),
};
function s([kind, minutes]: (string | number)[]): PlannedStep {
  return { kind: kind as StepKind, minutes: minutes as number };
}

/** Planning templates to edit, not a prescription. Custom lengths scale the nearest preset. */
export function planTemplate(requested: number): PlannedStep[] {
  const total = Math.min(Math.max(Math.round(requested) || 0, minimumMinutes), maximumMinutes);
  if (presets[total]) return presets[total].map((p) => ({ ...p }));
  if (total < 10) return [{ kind: "arrival", minutes: 1 }, { kind: "focus", minutes: total - 2 }, { kind: "closing", minutes: 1 }];
  const base = presetMinutes.reduce((a, b) => (Math.abs(b - total) < Math.abs(a - total) ? b : a));
  const shape = presets[base];
  const baseTotal = shape.reduce((n, p) => n + p.minutes, 0);
  const exact = shape.map((p) => (p.minutes * total) / baseTotal);
  const minutes = exact.map((e) => Math.max(1, Math.floor(e)));
  let remaining = total - minutes.reduce((a, b) => a + b, 0);
  const byRemainder = exact.map((_, i) => i).sort((a, b) => (exact[b] - Math.floor(exact[b])) - (exact[a] - Math.floor(exact[a])));
  for (let c = 0; remaining > 0; c++, remaining--) minutes[byRemainder[c % byRemainder.length]] += 1;
  if (remaining < 0) minutes[shape.findIndex((p) => p.kind === "focus")] += remaining;
  return shape.map((p, i) => ({ kind: p.kind, minutes: minutes[i] }));
}

// ---------- clock ----------
/** Two stored values; elapsed time always comes from the wall clock, so a reload loses nothing. */
export interface Clock { accumulated: number; runningSince: number | null }
export const Clock = {
  started: (t: number): Clock => ({ accumulated: 0, runningSince: t }),
  elapsed(c: Clock, now: number): number {
    return c.runningSince == null ? c.accumulated : c.accumulated + Math.max(0, now - c.runningSince);
  },
  pause(c: Clock, now: number): Clock {
    return c.runningSince == null ? c : { accumulated: Clock.elapsed(c, now), runningSince: null };
  },
  resume(c: Clock, now: number): Clock {
    return c.runningSince != null ? c : { ...c, runningSince: now };
  },
  format(ms: number): string {
    const secs = Math.floor(Math.max(0, ms) / 1000);
    const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60), sec = secs % 60;
    const pad = (n: number) => String(n).padStart(2, "0");
    return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${m}:${pad(sec)}`;
  },
  stepIndex(elapsedMs: number, steps: PlannedStep[]): number | null {
    if (!steps.length) return null;
    let boundary = 0;
    for (let i = 0; i < steps.length; i++) {
      boundary += steps[i].minutes * 60_000;
      if (elapsedMs < boundary) return i;
    }
    return steps.length - 1;
  },
};

export const retestIntervals = [
  { days: 1, label: "Tomorrow" },
  { days: 3, label: "In 3 days" },
  { days: 7, label: "In a week" },
  { days: 28, label: "In 4 weeks" },
];
/** Due dates land at the start of a day. */
export const retestDue = (from: number, days: number) => addDays(startOfDay(from), days);

// ---------- suggestions ----------
export interface TaskSnapshot {
  id: string;
  title: string;
  skillName: string | null;
  skillIsBottleneck: boolean;
  createdAt: number;
  lastAttemptAt: number | null;
  lastColdAttemptAt: number | null;
  nextStep: string | null;
  isArchived: boolean;
}
export interface RetestSnapshot { id: string; taskId: string; taskTitle: string; dueDate: number; scheduledAt: number; isCompleted: boolean }
export type Rule = "retestDue" | "bottleneckTask" | "bottleneckNeedsTask" | "unfinishedNextStep" | "notTriedColdLately";
export interface Suggestion { rule: Rule; taskId: string | null; retestId: string | null; title: string; reason: string }

export const staleColdDays = 14;
export const freshNextStepDays = 21;
export const rulesDescription = [
  "A cold retest you scheduled is due.",
  "You marked a skill as your bottleneck: the task linked to it you worked on most recently, or a nudge to pick one.",
  `The most recent task where you wrote a next step, within the last ${freshNextStepDays} days.`,
  `A task you haven't tried cold in ${staleColdDays} days or more.`,
  "Otherwise, nothing. You get the inventory or Just play instead of an invented task.",
];

const lowerFirst = (t: string) =>
  t.length > 1 && t[0] !== t[0].toLowerCase() && t[1] === t[1].toLowerCase()
    ? t[0].toLowerCase() + t.slice(1)
    : t;

export function suggest(tasks: TaskSnapshot[], retests: RetestSnapshot[], bottleneck: string | null, now: number): Suggestion | null {
  const active = tasks.filter((t) => !t.isArchived);
  const activeIds = new Set(active.map((t) => t.id));

  const due = retests
    .filter((r) => !r.isCompleted && r.dueDate <= now && activeIds.has(r.taskId))
    .sort((a, b) => a.dueDate - b.dueDate)[0];
  if (due) {
    return { rule: "retestDue", taskId: due.taskId, retestId: due.id, title: due.taskTitle,
      reason: `You set up this cold retest ${DayPhrase.since(due.scheduledAt, now)}.` };
  }

  if (bottleneck) {
    const linked = active.filter((t) => t.skillIsBottleneck)
      .sort((a, b) => (b.lastAttemptAt ?? b.createdAt) - (a.lastAttemptAt ?? a.createdAt))[0];
    if (linked) {
      return { rule: "bottleneckTask", taskId: linked.id, retestId: null, title: linked.title,
        reason: `Because you marked ${lowerFirst(bottleneck)} as your bottleneck.` };
    }
    return { rule: "bottleneckNeedsTask", taskId: null, retestId: null, title: bottleneck,
      reason: `Because you marked ${lowerFirst(bottleneck)} as your bottleneck. Pick one passage where it shows up.` };
  }

  const freshCutoff = addDays(now, -freshNextStepDays);
  const withNext = active
    .filter((t) => !isBlank(t.nextStep) && (t.lastAttemptAt ?? -Infinity) >= freshCutoff)
    .sort((a, b) => (b.lastAttemptAt ?? 0) - (a.lastAttemptAt ?? 0))[0];
  if (withNext && withNext.lastAttemptAt != null) {
    return { rule: "unfinishedNextStep", taskId: withNext.id, retestId: null, title: withNext.title,
      reason: `You left yourself a next step ${DayPhrase.since(withNext.lastAttemptAt, now)}: “${withNext.nextStep!.trim()}”` };
  }

  const staleCutoff = addDays(now, -staleColdDays);
  const stale = active
    .filter((t) => t.lastAttemptAt != null && (t.lastColdAttemptAt ?? -Infinity) <= staleCutoff)
    .sort((a, b) => (a.lastColdAttemptAt ?? -Infinity) - (b.lastColdAttemptAt ?? -Infinity))[0];
  if (stale) {
    const reason = stale.lastColdAttemptAt != null
      ? `You haven't tried this cold since ${DayPhrase.since(stale.lastColdAttemptAt, now)}.`
      : "You've practised this but haven't tried it cold yet.";
    return { rule: "notTriedColdLately", taskId: stale.id, retestId: null, title: stale.title, reason };
  }
  return null;
}

export function nextUpcomingRetest(retests: RetestSnapshot[], now: number): RetestSnapshot | null {
  return retests.filter((r) => !r.isCompleted && r.dueDate > now).sort((a, b) => a.dueDate - b.dueDate)[0] ?? null;
}

// ---------- evidence ----------
export interface EvidencePoint {
  id: string; taskId: string; date: number; phase: AttemptPhase;
  tempo: number | null; observation: string; nextStep: string;
}
export interface BeforeNow { taskId: string; phase: AttemptPhase; before: EvidencePoint; now: EvidencePoint; next: string | null }
export const tempoChange = (p: BeforeNow) =>
  p.before.tempo != null && p.now.tempo != null ? p.now.tempo - p.before.tempo : null;

function pairIn(group: EvidencePoint[]): [EvidencePoint, EvidencePoint] | null {
  if (group.length < 2) return null;
  const sorted = [...group].sort((a, b) => a.date - b.date);
  const first = sorted[0], last = sorted[sorted.length - 1];
  return sameDay(first.date, last.date) ? null : [first, last];
}
function latestNext(taskId: string, points: EvidencePoint[]): string | null {
  const p = points.filter((x) => x.taskId === taskId && !isBlank(x.nextStep)).sort((a, b) => b.date - a.date)[0];
  return p ? p.nextStep.trim() : null;
}

/** Same task, same phase, different days. Cold is never compared with after-practice. */
export function pairsForTask(taskId: string, points: EvidencePoint[]): BeforeNow[] {
  const next = latestNext(taskId, points);
  return (["cold", "afterPractice"] as AttemptPhase[]).flatMap((phase) => {
    const pair = pairIn(points.filter((p) => p.taskId === taskId && p.phase === phase));
    return pair ? [{ taskId, phase, before: pair[0], now: pair[1], next }] : [];
  });
}

export function latestPair(points: EvidencePoint[]): BeforeNow | null {
  let best: BeforeNow | null = null;
  for (const taskId of new Set(points.map((p) => p.taskId))) {
    for (const c of pairsForTask(taskId, points)) {
      if (!best || c.now.date > best.now.date || (c.now.date === best.now.date && c.phase === "cold" && best.phase !== "cold")) best = c;
    }
  }
  return best;
}

export const longGapDays = 7;
export const isLongGap = (lastPlayed: number | null, now: number) =>
  lastPlayed != null && daysBetween(lastPlayed, now) >= longGapDays;
/** A gap is ordinary: never counts missed days or mentions streaks. */
export function greeting(lastPlayed: number | null, now: number): string {
  if (isLongGap(lastPlayed, now)) return "Welcome back.";
  const h = new Date(now).getHours();
  return h >= 5 && h < 12 ? "Good morning." : h >= 12 && h < 18 ? "Good afternoon." : "Good evening.";
}
