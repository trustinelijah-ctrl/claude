// JSON export in the same format as the iOS app (PianoCore/ExportBundle.swift).
import { Clock } from "./core/logic";
import type { DB } from "./store";

const iso = (t: number | null) => (t == null ? null : new Date(t).toISOString().replace(/\.\d{3}Z$/, "Z"));
const planText = (d: DB["sessions"][number]) => d.plan.map((p) => `${p.kind}:${p.minutes}`).join(",");

export function makeBundle(d: DB, now = Date.now()) {
  return {
    format: "piano-deeply-export",
    version: 1,
    exportedAt: iso(now),
    source: "web",
    audioNote: "Audio files are not embedded. Download a recording from the Journal to get its file; the recording id is in its file name.",
    skills: d.skills.map((s) => ({ id: s.id, branch: s.branch, name: s.name, evidence: s.evidence, state: s.state, isBottleneck: s.isBottleneck })),
    pieces: d.pieces.map((p) => ({ id: p.id, title: p.title, composer: p.composer, notes: p.notes, isCurrent: p.isCurrent, createdAt: iso(p.createdAt) })),
    tasks: d.tasks.map((t) => ({ id: t.id, title: t.title, context: t.contextNote, skillID: t.skillId, pieceID: t.pieceId, inventorySample: t.inventorySample, isArchived: t.isArchived, createdAt: iso(t.createdAt) })),
    sessions: d.sessions.map((s) => ({
      id: s.id, kind: s.kind, startedAt: iso(s.startedAt), endedAt: iso(s.endedAt), plannedMinutes: s.plan.reduce((n, p) => n + p.minutes, 0),
      practisedSeconds: Math.floor(Clock.elapsed(s.clock, s.endedAt ?? now) / 1000), plan: planText(s), focusTaskID: s.focusTaskId,
      smallerExercise: s.smaller, correction: s.correction, variation: s.variation, backIntoMusic: s.reintegration,
      stepNotes: s.stepNotes, whatGotEasier: s.closingEasier, nextTime: s.closingNext,
    })),
    attempts: d.attempts.map((a) => ({
      id: a.id, taskID: a.taskId, sessionID: a.sessionId, date: iso(a.date), phase: a.isRetest ? "coldRetest" : a.phase, tempo: a.tempo,
      errorCategory: a.errorCategory, observation: a.observation, smallerExercise: a.smallerExercise, outcome: a.outcome, nextStep: a.nextStep,
    })),
    retests: d.retests.map((r) => ({ id: r.id, taskID: r.taskId, scheduledAt: iso(r.scheduledAt), dueDate: iso(r.dueDate), context: r.context, completedAttemptID: r.resultAttemptId })),
    recordings: d.recordings.map((r) => ({ id: r.id, fileName: r.id, mimeType: r.mimeType, createdAt: iso(r.createdAt), durationSeconds: r.duration, title: r.title, taskID: r.taskId, attemptID: r.attemptId, sessionID: r.sessionId })),
    notes: d.notes.map((n) => ({ id: n.id, date: iso(n.date), text: n.text })),
  };
}

export function downloadExport(d: DB) {
  const blob = new Blob([JSON.stringify(makeBundle(d), null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `PianoDeeply-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 10_000);
}
