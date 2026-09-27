// Everything the web app saves, in one JSON document in localStorage.
// Audio blobs live in IndexedDB (see audio.ts). Mirrors the SwiftData models.
import { useSyncExternalStore } from "react";
import {
  Clock, isBlank, planTemplate, retestDue, type EvidencePoint, type PlannedStep, type RetestSnapshot, type TaskSnapshot,
} from "./core/logic";
import {
  branches, phaseLabel, errorInfo, starterSubskills,
  type AttemptPhase, type ErrorCategory, type InventorySample, type Outcome, type SkillBranch, type SkillState,
} from "./core/vocab";

export interface Skill { id: string; branch: SkillBranch; name: string; evidence: string; state: SkillState; isBottleneck: boolean; sortOrder: number; createdAt: number }
export interface Task { id: string; title: string; contextNote: string; createdAt: number; isArchived: boolean; inventorySample: InventorySample | null; skillId: string | null; pieceId: string | null }
export interface Attempt {
  id: string; taskId: string | null; sessionId: string | null; date: number; phase: AttemptPhase; tempo: number | null;
  errorCategory: ErrorCategory | null; observation: string; smallerExercise: string; outcome: Outcome | null; nextStep: string; isRetest: boolean;
}
export interface Retest { id: string; taskId: string; scheduledAt: number; dueDate: number; context: string; completedAt: number | null; resultAttemptId: string | null }
export interface Session {
  id: string; kind: "practice" | "justPlay"; startedAt: number; endedAt: number | null; plan: PlannedStep[]; currentStep: number;
  clock: Clock; focusTaskId: string | null; smaller: string; correction: string; variation: string; reintegration: string;
  stepNotes: Record<string, string>; closingEasier: string; closingNext: string;
}
export interface Recording { id: string; createdAt: number; duration: number; title: string; mimeType: string; taskId: string | null; attemptId: string | null; sessionId: string | null }
export interface Piece { id: string; title: string; composer: string; notes: string; isCurrent: boolean; createdAt: number }
export interface JournalNote { id: string; date: number; text: string }

export interface DB {
  version: 1;
  skills: Skill[]; tasks: Task[]; attempts: Attempt[]; retests: Retest[]; sessions: Session[];
  recordings: Recording[]; pieces: Piece[]; notes: JournalNote[];
  settings: { hasSeenWelcome: boolean; inventoryHidden: boolean; lastSessionMinutes: number; justPlayShowsTimer: boolean };
}

const KEY = "piano-deeply.v1";
export const uid = () => crypto.randomUUID();

function starterSkills(now: number): Skill[] {
  return branches.flatMap((branch) =>
    starterSubskills[branch].map(([name, evidence], i) => ({
      id: uid(), branch, name, evidence, state: "notExplored" as SkillState, isBottleneck: false, sortOrder: i, createdAt: now,
    })),
  );
}

export function emptyDB(now = Date.now()): DB {
  return {
    version: 1, skills: starterSkills(now), tasks: [], attempts: [], retests: [], sessions: [], recordings: [], pieces: [], notes: [],
    settings: { hasSeenWelcome: false, inventoryHidden: false, lastSessionMinutes: 30, justPlayShowsTimer: false },
  };
}

function load(): DB {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as DB;
      if (parsed.version === 1) return { ...emptyDB(), ...parsed, settings: { ...emptyDB().settings, ...parsed.settings } };
    }
  } catch { /* storage blocked or corrupt: start fresh in memory */ }
  return emptyDB();
}

let db: DB = load();
let saveError: string | null = null;
const listeners = new Set<() => void>();

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(db));
    saveError = null;
  } catch {
    saveError = "This browser isn't letting the app save. Your changes will be lost when you close the tab. Export a copy from Settings.";
  }
}

/** Apply a change to a copy and save it immediately, so nothing typed is lost on reload. */
export function update(change: (draft: DB) => void) {
  const draft = structuredClone(db);
  change(draft);
  db = draft;
  persist();
  listeners.forEach((l) => l());
}

export function replaceAll(next: DB) {
  db = next;
  persist();
  listeners.forEach((l) => l());
}

export const getDB = () => db;
export const getSaveError = () => saveError;
const subscribe = (l: () => void) => (listeners.add(l), () => listeners.delete(l));
export const useDB = () => useSyncExternalStore(subscribe, getDB);

// Another tab saved: pick it up.
window.addEventListener("storage", (e) => {
  if (e.key === KEY) { db = load(); listeners.forEach((l) => l()); }
});

// ---------- mutations with delete rules matching the iOS app ----------

/** Deleting a target removes its attempts and retests; its recordings and sessions stay. */
export function deleteTask(d: DB, id: string) {
  const attemptIds = new Set(d.attempts.filter((a) => a.taskId === id).map((a) => a.id));
  d.tasks = d.tasks.filter((t) => t.id !== id);
  d.attempts = d.attempts.filter((a) => a.taskId !== id);
  d.retests = d.retests.filter((r) => r.taskId !== id);
  d.recordings.forEach((r) => {
    if (r.taskId === id) r.taskId = null;
    if (r.attemptId && attemptIds.has(r.attemptId)) r.attemptId = null;
  });
  d.sessions.forEach((s) => { if (s.focusTaskId === id) s.focusTaskId = null; });
}
export function deleteAttempt(d: DB, id: string) {
  d.attempts = d.attempts.filter((a) => a.id !== id);
  d.recordings.forEach((r) => { if (r.attemptId === id) r.attemptId = null; });
}
export function deleteSession(d: DB, id: string) {
  d.sessions = d.sessions.filter((s) => s.id !== id);
  d.attempts.forEach((a) => { if (a.sessionId === id) a.sessionId = null; });
  d.recordings.forEach((r) => { if (r.sessionId === id) r.sessionId = null; });
}
export function deletePiece(d: DB, id: string) {
  d.pieces = d.pieces.filter((p) => p.id !== id);
  d.tasks.forEach((t) => { if (t.pieceId === id) t.pieceId = null; });
}
export function deleteSkill(d: DB, id: string) {
  d.skills = d.skills.filter((s) => s.id !== id);
  d.tasks.forEach((t) => { if (t.skillId === id) t.skillId = null; });
}
/** One bottleneck at a time; marking the current one again clears it. */
export function toggleBottleneck(d: DB, id: string) {
  const target = d.skills.find((s) => s.id === id);
  if (!target) return;
  const next = !target.isBottleneck;
  d.skills.forEach((s) => { s.isBottleneck = false; });
  target.isBottleneck = next;
}

export function newTask(title: string, extra: Partial<Task> = {}): Task {
  return { id: uid(), title: title.trim(), contextNote: "", createdAt: Date.now(), isArchived: false, inventorySample: null, skillId: null, pieceId: null, ...extra };
}
export function newAttempt(taskId: string | null, phase: AttemptPhase, extra: Partial<Attempt> = {}): Attempt {
  return {
    id: uid(), taskId, sessionId: null, date: Date.now(), phase, tempo: null, errorCategory: null, observation: "",
    smallerExercise: "", outcome: null, nextStep: "", isRetest: false, ...extra,
  };
}
export function newSession(kind: Session["kind"], plan: PlannedStep[] = [], focusTaskId: string | null = null, now = Date.now()): Session {
  return {
    id: uid(), kind, startedAt: now, endedAt: null, plan, currentStep: 0, clock: Clock.started(now), focusTaskId,
    smaller: "", correction: "", variation: "", reintegration: "", stepNotes: {}, closingEasier: "", closingNext: "",
  };
}
export { planTemplate };

// ---------- derived views ----------

export const attemptsFor = (d: DB, taskId: string) => d.attempts.filter((a) => a.taskId === taskId).sort((a, b) => b.date - a.date);
export const lastColdAttempt = (d: DB, taskId: string) => attemptsFor(d, taskId).find((a) => a.phase === "cold") ?? null;
export const pendingRetests = (d: DB, taskId: string) =>
  d.retests.filter((r) => r.taskId === taskId && r.completedAt == null).sort((a, b) => a.dueDate - b.dueDate);
export const attemptLabel = (a: Attempt) => (a.isRetest ? "Cold retest" : phaseLabel[a.phase]);
export const plannedMinutes = (s: Session) => s.plan.reduce((n, p) => n + p.minutes, 0);
export const minutesText = (s: Session, now = Date.now()) => {
  const m = Math.round(Clock.elapsed(s.clock, s.endedAt ?? now) / 60_000);
  return m < 1 ? "under a minute" : `${m} min`;
};
export const recordingFor = (d: DB, attemptId: string) =>
  d.recordings.filter((r) => r.attemptId === attemptId).sort((a, b) => b.createdAt - a.createdAt)[0] ?? null;

export function contextSummary(d: DB, t: Task): string {
  const piece = d.pieces.find((p) => p.id === t.pieceId);
  return [piece?.title, isBlank(t.contextNote) ? null : t.contextNote].filter(Boolean).join(" · ");
}

/**
 * The newest thing done on a task and its next step. Attempts always count; a
 * focus session counts only if its closing note says what's next. A blank next
 * step on the latest attempt means nothing is pending, however old ones read.
 */
export function taskSnapshot(d: DB, t: Task): TaskSnapshot {
  const skill = d.skills.find((s) => s.id === t.skillId);
  const activity = [
    ...d.attempts.filter((a) => a.taskId === t.id).map((a) => ({ date: a.date, next: a.nextStep })),
    ...d.sessions.filter((s) => s.focusTaskId === t.id && !isBlank(s.closingNext)).map((s) => ({ date: s.endedAt ?? s.startedAt, next: s.closingNext })),
  ].sort((a, b) => b.date - a.date)[0];
  return {
    id: t.id, title: t.title, skillName: skill?.name ?? null, skillIsBottleneck: skill?.isBottleneck ?? false,
    createdAt: t.createdAt, lastAttemptAt: activity?.date ?? null, lastColdAttemptAt: lastColdAttempt(d, t.id)?.date ?? null,
    nextStep: activity && !isBlank(activity.next) ? activity.next : null, isArchived: t.isArchived,
  };
}

export function retestSnapshots(d: DB): RetestSnapshot[] {
  return d.retests.flatMap((r) => {
    const t = d.tasks.find((x) => x.id === r.taskId);
    return t ? [{ id: r.id, taskId: t.id, taskTitle: t.title, dueDate: r.dueDate, scheduledAt: r.scheduledAt, isCompleted: r.completedAt != null }] : [];
  });
}

export const evidencePoints = (d: DB): EvidencePoint[] =>
  d.attempts.flatMap((a) => (a.taskId ? [{ id: a.id, taskId: a.taskId, date: a.date, phase: a.phase, tempo: a.tempo, observation: a.observation, nextStep: a.nextStep }] : []));

/** "After practice, 12 Sep · 72 bpm · hands together · “…”" */
export function retestContext(a: Attempt | null | undefined): string {
  if (!a) return "";
  const parts = [`${attemptLabel(a)}, ${new Date(a.date).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" })}`];
  if (a.tempo != null) parts.push(`${a.tempo} bpm`);
  if (a.errorCategory) parts.push(errorInfo[a.errorCategory].label.toLowerCase());
  if (!isBlank(a.observation)) parts.push(`“${a.observation.trim()}”`);
  return parts.join(" · ");
}

export function scheduleRetest(d: DB, taskId: string, days: number, context: string, now = Date.now()) {
  const due = retestDue(now, days);
  if (d.retests.some((r) => r.taskId === taskId && r.completedAt == null && r.dueDate === due)) return;
  d.retests.push({ id: uid(), taskId, scheduledAt: now, dueDate: due, context, completedAt: null, resultAttemptId: null });
}
