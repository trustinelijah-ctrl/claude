import { useState } from "react";
import { DayPhrase, isBlank, pairsForTask, presetMinutes, maximumMinutes, minimumMinutes, planTemplate, retestIntervals, retestDue, suggest, type PlannedStep, type Suggestion } from "../core/logic";
import { errorCategories, errorInfo, outcomeLabel, outcomes, feedbackAfter, phaseLabel, stepInfo, branches, branchInfo, type AttemptPhase, type ErrorCategory, type Outcome } from "../core/vocab";
import {
  attemptsFor, contextSummary, deleteAttempt, deletePiece, deleteTask, evidencePoints, getDB, newAttempt, newSession, newTask,
  pendingRetests, recordingFor, retestContext, retestSnapshots, scheduleRetest, taskSnapshot, update, useDB, uid,
  type Attempt, type DB, type Recording, type Retest, type Session,
} from "../store";
import { stopIfOwnedBy } from "../audio";
import { useNav } from "../nav";
import { Chip, FlowRow, Icon, NavBar, PhaseBadge, PlayButton, RecordControl, RecordingRow, Section, SheetBar, TempoField, fmtDate, fmtTime, parseTempo } from "../ui";
import { ActiveSession, JustPlay } from "./session";
import { BeforeNowCard } from "./journal";

// ---------- shared actions ----------
export function currentSuggestion(d: DB, now = Date.now()): Suggestion | null {
  return suggest(d.tasks.map((t) => taskSnapshot(d, t)), retestSnapshots(d), d.skills.find((s) => s.isBottleneck)?.name ?? null, now);
}
export const runningSession = (d: DB) => d.sessions.find((s) => s.endedAt == null) ?? null;

export function useActions() {
  const nav = useNav();
  const open = (s: Session) => nav.openCover(s.kind === "justPlay" ? <JustPlay id={s.id} /> : <ActiveSession id={s.id} />);
  return {
    open,
    planSession: (focusTaskId?: string) => nav.openSheet(<SessionSetup preselected={focusTaskId ?? null} />),
    /** One live session at a time: if something is running, return to it. */
    startJustPlay: () => {
      const running = runningSession(getDB());
      if (running) return open(running);
      const s = newSession("justPlay");
      update((d) => { d.sessions.push(s); });
      nav.openCover(<JustPlay id={s.id} />);
    },
  };
}

// ---------- Practice tab ----------
export function PracticeHome() {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const active = [...d.tasks].filter((t) => !t.isArchived).sort((a, b) => b.createdAt - a.createdAt);
  const archived = d.tasks.filter((t) => t.isArchived);
  const [showArchived, setShowArchived] = useState(false);
  return (
    <div className="screen-body">
      <NavBar />
      <h1 className="large-title">Practice</h1>
      <div className="pad stack" style={{ ["--gap" as string]: "10px" }}>
        <button className="btn-primary" onClick={() => actions.planSession()}>Plan a session</button>
        <button className="btn-secondary" onClick={actions.startJustPlay}><Icon name="note" />Just play</button>
      </div>
      <div className="list">
        <Section header="Targets">
          {!active.length && <div className="cell soft">A target is something you could check: “bars 9–12, hands together, no stops at 60”.</div>}
          {active.map((t) => <TaskRow key={t.id} id={t.id} />)}
          <button className="cell link-cell" onClick={() => nav.openSheet(<TaskEditor />)}><Icon name="plus" />New target</button>
        </Section>
        <Section header="Pieces">
          {!d.pieces.length && <div className="cell soft">Add the pieces you're learning or keeping up. They show up on Today.</div>}
          {[...d.pieces].sort((a, b) => b.createdAt - a.createdAt).map((p) => (
            <button key={p.id} className="cell nav-cell" onClick={() => nav.push(<PieceDetail id={p.id} />)}>
              <div className="grow">
                <div style={{ fontWeight: 500 }}>{p.title} {p.isCurrent && <span className="badge warm">Current</span>}</div>
                {p.composer && <div className="sub soft">{p.composer}</div>}
              </div>
              <Icon name="chev" />
            </button>
          ))}
          <button className="cell link-cell" onClick={() => nav.openSheet(<PieceEditor />)}><Icon name="plus" />Add piece</button>
        </Section>
        {archived.length > 0 && (
          <Section>
            <button className="cell link-cell" onClick={() => setShowArchived(!showArchived)}>
              <Icon name={showArchived ? "down" : "chev"} />Archived targets ({archived.length})
            </button>
            {showArchived && archived.map((t) => <TaskRow key={t.id} id={t.id} />)}
          </Section>
        )}
      </div>
    </div>
  );
}

export function TaskRow({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const t = d.tasks.find((x) => x.id === id);
  if (!t) return null;
  const skill = d.skills.find((s) => s.id === t.skillId);
  const last = attemptsFor(d, t.id)[0];
  return (
    <button className="cell nav-cell" onClick={() => nav.push(<TaskDetail id={t.id} />)}>
      <div className="grow">
        <div style={{ fontWeight: 500 }}>{t.title}</div>
        <div className="sub soft">
          {[skill?.name, last ? `last ${DayPhrase.since(last.date, Date.now())}` : "not tried yet"].filter(Boolean).join(" · ")}
          {pendingRetests(d, t.id).length > 0 && <> · <Icon name="snowflake" /></>}
        </div>
      </div>
      <Icon name="chev" />
    </button>
  );
}

// ---------- session setup ----------
export function SessionSetup({ preselected }: { preselected: string | null }) {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const running = runningSession(d);
  const suggestion = currentSuggestion(d);
  const [minutes, setMinutes] = useState(d.settings.lastSessionMinutes);
  const [custom, setCustom] = useState(!presetMinutes.includes(d.settings.lastSessionMinutes));
  const [plan, setPlan] = useState<PlannedStep[]>(() => planTemplate(d.settings.lastSessionMinutes));
  const initialFocus = (() => {
    const id = preselected ?? suggestion?.taskId ?? null;
    return id && d.tasks.some((t) => t.id === id) ? id : "later";
  })();
  const [focus, setFocus] = useState<string>(initialFocus);
  const [newTarget, setNewTarget] = useState("");
  const total = plan.reduce((n, p) => n + p.minutes, 0);

  const setLength = (m: number) => { setMinutes(m); setPlan(planTemplate(m)); };

  // The suggested task, then whatever is selected, then recent ones.
  const pinned = [suggestion?.taskId, focus].filter((x, i, a): x is string => !!x && x !== "later" && x !== "new" && a.indexOf(x) === i);
  const options = [
    ...pinned.flatMap((id) => d.tasks.filter((t) => t.id === id)),
    ...d.tasks.filter((t) => !t.isArchived && !pinned.includes(t.id)).sort((a, b) => b.createdAt - a.createdAt).slice(0, 8),
  ];

  const begin = () => {
    let focusId: string | null = focus === "later" ? null : focus;
    const session = newSession("practice", plan);
    update((db) => {
      if (focus === "new") {
        const t = newTask(newTarget);
        db.tasks.push(t);
        focusId = t.id;
      }
      session.focusTaskId = focusId;
      db.sessions.push(session);
      db.settings.lastSessionMinutes = minutes;
    });
    nav.closeSheet();
    nav.openCover(<ActiveSession id={session.id} />);
  };

  return (
    <div className="sheet-body">
      <SheetBar title="Plan a session" />
      <div className="list">
        {running ? (
          <Section>
            <div className="cell">{running.kind === "justPlay" ? "You're in Just play." : "A session is already running."}</div>
            <button className="cell link-cell" onClick={() => { nav.closeSheet(); actions.open(running); }}>Return to it</button>
          </Section>
        ) : (
          <>
            <Section header="How long">
              <div className="cell">
                <FlowRow>
                  {presetMinutes.map((m) => <Chip key={m} label={`${m} min`} on={!custom && minutes === m} onClick={() => { setCustom(false); setLength(m); }} />)}
                  <Chip label="Custom" on={custom} onClick={() => setCustom(true)} />
                </FlowRow>
              </div>
              {custom && (
                <div className="cell">
                  <span className="grow">{minutes} minutes</span>
                  <Stepper value={minutes} min={minimumMinutes} max={maximumMinutes} step={5} onChange={setLength} label="Session length" />
                </div>
              )}
            </Section>
            <Section header="One focused problem">
              {options.map((t) => (
                <button key={t.id} className="cell choice" aria-pressed={focus === t.id} onClick={() => setFocus(t.id)}>
                  <div className="grow">
                    <div>{t.title}</div>
                    {t.id === suggestion?.taskId && <div className="foot soft">{suggestion.reason}</div>}
                  </div>
                  {focus === t.id && <span className="check"><Icon name="check" stroke={2.4} /></span>}
                </button>
              ))}
              <button className="cell choice" aria-pressed={focus === "new"} onClick={() => setFocus("new")}>
                <div className="grow">Something new…</div>{focus === "new" && <span className="check"><Icon name="check" stroke={2.4} /></span>}
              </button>
              {focus === "new" && (
                <div className="cell">
                  <textarea className="inline-input" rows={2} autoFocus value={newTarget} onChange={(e) => setNewTarget(e.target.value)}
                    placeholder="Something you could check, like “bars 9–12, hands together, no stops”" />
                </div>
              )}
              <button className="cell choice" aria-pressed={focus === "later"} onClick={() => setFocus("later")}>
                <div className="grow">Decide during the session</div>{focus === "later" && <span className="check"><Icon name="check" stroke={2.4} /></span>}
              </button>
            </Section>
            <Section header="Plan" footer="A starting shape to change, not a rule. Adjust the minutes, or remove a step.">
              {plan.map((step, i) => (
                <div key={step.kind} className="cell">
                  <span style={{ color: "var(--forest)" }}><Icon name={stepInfo[step.kind].icon} /></span>
                  <span className="grow">{stepInfo[step.kind].title}</span>
                  <span className="soft mono">{step.minutes} min</span>
                  <Stepper value={step.minutes} min={1} max={120} label={stepInfo[step.kind].title}
                    onChange={(v) => setPlan(plan.map((p, j) => (j === i ? { ...p, minutes: v } : p)))} />
                  <button className="icon-btn" aria-label={`Remove ${stepInfo[step.kind].title}`} onClick={() => setPlan(plan.filter((_, j) => j !== i))}>
                    <Icon name="trash" />
                  </button>
                </div>
              ))}
              {plan.length === 0 && <div className="cell soft">No steps left. Pick a length above to start again.</div>}
            </Section>
            <div className="pad" style={{ marginTop: 20 }}>
              <button className="btn-primary" disabled={!plan.length || (focus === "new" && isBlank(newTarget))} onClick={begin}>
                Begin · {total} min
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

export function Stepper({ value, min, max, step = 1, onChange, label }: { value: number; min: number; max: number; step?: number; onChange: (v: number) => void; label: string }) {
  return (
    <div className="stepper" role="group" aria-label={label}>
      <button aria-label={`Less ${label}`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - step))}>−</button>
      <button aria-label={`More ${label}`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + step))}>+</button>
    </div>
  );
}

// ---------- log attempt ----------
export function LogAttempt({ taskId, phase: initialPhase, sessionId = null, retestId = null, smaller = "" }: {
  taskId: string; phase: AttemptPhase; sessionId?: string | null; retestId?: string | null; smaller?: string;
}) {
  const d = useDB();
  const nav = useNav();
  const task = d.tasks.find((t) => t.id === taskId);
  const retest = d.retests.find((r) => r.id === retestId) ?? null;
  const [phase, setPhase] = useState<AttemptPhase>(retest ? "cold" : initialPhase);
  const [tempo, setTempo] = useState("");
  const [category, setCategory] = useState<ErrorCategory | "">("");
  const [observation, setObservation] = useState("");
  const [smallerExercise, setSmaller] = useState(smaller);
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [nextStep, setNextStep] = useState("");
  const [take, setTake] = useState<Recording | null>(null);
  const owner = `attempt-${taskId}`;
  if (!task) return null;

  const close = () => { void stopIfOwnedBy(owner); nav.closeSheet(); };
  const save = async () => {
    const finished = (await stopIfOwnedBy(owner)) ?? take;
    const attempt = newAttempt(task.id, phase, {
      sessionId, tempo: parseTempo(tempo), errorCategory: category || null, observation: observation.trim(),
      smallerExercise: phase === "afterPractice" ? smallerExercise.trim() : "", outcome, nextStep: nextStep.trim(), isRetest: !!retest,
    });
    update((db) => {
      db.attempts.push(attempt);
      const rec = finished && db.recordings.find((r) => r.id === finished.id);
      if (rec) rec.attemptId = attempt.id;
      const r = retest && db.retests.find((x) => x.id === retest.id);
      if (r) { r.completedAt = attempt.date; r.resultAttemptId = attempt.id; }
    });
    nav.closeSheet();
    if (outcome) nav.showFeedback(feedbackAfter(outcome, attempt.tempo, phase));
  };

  return (
    <div className="sheet-body">
      <SheetBar title={retest ? "Cold retest" : "Log attempt"} onCancel={close} action={() => void save()} />
      <div className="list">
        <Section>
          <div className="cell block">
            <div className="headline">{task.title}</div>
            {contextSummary(d, task) && <div className="sub soft">{contextSummary(d, task)}</div>}
          </div>
          {retest && (
            <div className="cell block">
              <div className="sub" style={{ fontWeight: 600 }}>Set up {DayPhrase.since(retest.scheduledAt, Date.now())}</div>
              {retest.context && <div className="sub soft">{retest.context}</div>}
            </div>
          )}
        </Section>
        <Section footer={phase === "cold" ? "Cold means your first go at this today, with no warm-up on it." : "After you've worked on it. Compared only with other after-practice attempts."}>
          <div className="cell">
            <div className="seg" role="radiogroup" aria-label="Kind of attempt">
              {(["cold", "afterPractice"] as AttemptPhase[]).map((p) => (
                <button key={p} role="radio" aria-checked={phase === p} className={phase === p ? "on" : ""} disabled={!!retest} onClick={() => setPhase(p)}>{phaseLabel[p]}</button>
              ))}
            </div>
          </div>
        </Section>
        <Section header="How it went">
          <TempoField value={tempo} onChange={setTempo} />
          <label className="cell">
            <span className="grow">What got in the way</span>
            <select className="inline-select" value={category} onChange={(e) => setCategory(e.target.value as ErrorCategory | "")}>
              <option value="">Nothing in particular</option>
              {errorCategories.map((c) => <option key={c} value={c}>{errorInfo[c].label}</option>)}
            </select>
          </label>
          <div className="cell"><textarea className="inline-input" rows={3} value={observation} onChange={(e) => setObservation(e.target.value)} placeholder="What happened? Be specific: which beat, which hand." /></div>
          {phase === "afterPractice" && (
            <div className="cell"><textarea className="inline-input" rows={2} value={smallerExercise} onChange={(e) => setSmaller(e.target.value)} placeholder="The smaller exercise you used" /></div>
          )}
        </Section>
        <Section header={retest ? "Did it hold up cold?" : "Did the experiment work?"} footer="Optional. Leave it blank if this wasn't a specific experiment.">
          <div className="cell"><FlowRow>{outcomes.map((o) => <Chip key={o} label={outcomeLabel[o]} on={outcome === o} onClick={() => setOutcome(outcome === o ? null : o)} />)}</FlowRow></div>
        </Section>
        <Section header="Next step">
          <div className="cell"><textarea className="inline-input" rows={2} value={nextStep} onChange={(e) => setNextStep(e.target.value)} placeholder="One thing to try next time" /></div>
        </Section>
        <Section header="Recording (optional)">
          <div className="cell block">
            <RecordControl owner={owner} title={`${retest ? "Cold retest" : phaseLabel[phase]}: ${task.title}`} link={{ taskId: task.id, sessionId }} onFinished={setTake} />
          </div>
          {take && d.recordings.some((r) => r.id === take.id) && <RecordingRow recording={take} />}
        </Section>
        <div className="pad" style={{ marginTop: 20 }}><button className="btn-primary" onClick={() => void save()}>Save attempt</button></div>
      </div>
    </div>
  );
}

export function RetestPicker({ taskId }: { taskId: string }) {
  const d = useDB();
  const pending = pendingRetests(d, taskId);
  const now = Date.now();
  return (
    <div className="stack" style={{ ["--gap" as string]: "10px" }}>
      {pending[0] && (
        <div className="sub" style={{ color: "var(--forest)", fontWeight: 600, display: "flex", gap: 6, alignItems: "center" }}>
          <Icon name="snowflake" />Cold retest {DayPhrase.until(pending[0].dueDate, now)}
        </div>
      )}
      <FlowRow>
        {retestIntervals.map((iv) => {
          const scheduled = pending.some((r) => r.dueDate === retestDue(now, iv.days));
          return (
            <Chip key={iv.days} label={iv.label} on={scheduled}
              onClick={() => { if (!scheduled) update((db) => scheduleRetest(db, taskId, iv.days, retestContext(attemptsFor(db, taskId)[0]))); }} />
          );
        })}
      </FlowRow>
    </div>
  );
}

export function AttemptSummary({ attempt }: { attempt: Attempt }) {
  const d = useDB();
  const rec = recordingFor(d, attempt.id);
  return (
    <div className="surface stack" style={{ ["--gap" as string]: "6px", padding: 14 }}>
      <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
        <PhaseBadge attempt={attempt} />
        {attempt.tempo != null && <span className="sub soft mono">{attempt.tempo} bpm</span>}
        {attempt.outcome && <span className="sub soft" style={{ fontWeight: 500 }}>{outcomeLabel[attempt.outcome]}</span>}
      </div>
      {attempt.errorCategory && <div className="sub" style={{ fontWeight: 500 }}>{errorInfo[attempt.errorCategory].label}</div>}
      {!isBlank(attempt.observation) && <div>{attempt.observation}</div>}
      {!isBlank(attempt.nextStep) && <div className="sub soft">Next: {attempt.nextStep}</div>}
      {rec && <div><PlayButton recording={rec} /></div>}
    </div>
  );
}

// ---------- task detail ----------
export function TaskDetail({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const task = d.tasks.find((t) => t.id === id);
  if (!task) return <div className="screen-body"><NavBar back /><p className="pad soft">This target was deleted.</p></div>;
  const skill = d.skills.find((s) => s.id === task.skillId);
  const attempts = attemptsFor(d, id);
  const pairs = pairsForTask(id, evidencePoints(d));
  const others = d.recordings.filter((r) => r.taskId === id && !r.attemptId).sort((a, b) => b.createdAt - a.createdAt);

  const remove = () => {
    if (!confirm(`Delete “${task.title}”? Its attempts and retests are deleted. Recordings stay in the Journal.`)) return;
    nav.pop();
    update((db) => deleteTask(db, id));
  };

  return (
    <div className="screen-body">
      <NavBar back trailing={
        <>
          <button className="icon-btn" aria-label="Edit" onClick={() => nav.openSheet(<TaskEditor id={id} />)}><Icon name="pencil" /></button>
          <button className="icon-btn" aria-label={task.isArchived ? "Unarchive" : "Archive"} onClick={() => update((db) => { const t = db.tasks.find((x) => x.id === id); if (t) t.isArchived = !t.isArchived; })}><Icon name="archive" /></button>
          <button className="icon-btn danger" aria-label="Delete target" onClick={remove}><Icon name="trash" /></button>
        </>
      } />
      <div className="pad stack" style={{ ["--gap" as string]: "8px" }}>
        {task.isArchived && <span className="badge warm">Archived</span>}
        <h1 className="display-title">{task.title}</h1>
        {contextSummary(d, task) && <p className="soft">{contextSummary(d, task)}</p>}
        {skill && <p className="sub soft" style={{ display: "flex", gap: 6, alignItems: "center" }}><Icon name={branchInfo[skill.branch].icon} />{skill.name}</p>}
      </div>
      <div className="pad stack" style={{ ["--gap" as string]: "10px", marginTop: 18 }}>
        <button className="btn-primary" onClick={() => actions.planSession(id)}>Practise this now</button>
        <div className="row2">
          <button className="btn-secondary" onClick={() => nav.openSheet(<LogAttempt taskId={id} phase="cold" />)}>Log cold pass</button>
          <button className="btn-secondary" onClick={() => nav.openSheet(<LogAttempt taskId={id} phase="afterPractice" />)}>Log after practice</button>
        </div>
      </div>
      <div className="list">
        <Section header="Cold retests">
          {pendingRetests(d, id).map((r: Retest) => (
            <div key={r.id} className="cell block">
              <div className="sub" style={{ color: "var(--forest)", fontWeight: 600, display: "flex", gap: 6, alignItems: "center" }}>
                <Icon name="snowflake" />Due {DayPhrase.until(r.dueDate, Date.now())}
              </div>
              {r.context && <div className="sub">{r.context}</div>}
              <div className="row-actions">
                <button className="link small-btn" onClick={() => nav.openSheet(<LogAttempt taskId={id} phase="cold" retestId={r.id} />)}>Do the retest now</button>
                <button className="link small-btn danger" onClick={() => update((db) => { db.retests = db.retests.filter((x) => x.id !== r.id); })}>Remove</button>
              </div>
            </div>
          ))}
          <div className="cell block"><RetestPicker taskId={id} /></div>
        </Section>
        {pairs.length > 0 && (
          <Section header="Before and now">
            {pairs.map((p) => <div key={p.phase} className="cell block"><BeforeNowCard pair={p} /></div>)}
          </Section>
        )}
        <Section header="Attempts">
          {!attempts.length && <div className="cell soft">No attempts yet. A cold first pass is a good start: once through, before practising it.</div>}
          {attempts.map((a) => (
            <button key={a.id} className="cell nav-cell" onClick={() => nav.push(<AttemptEditor id={a.id} />)}>
              <AttemptListRow attempt={a} /><Icon name="chev" />
            </button>
          ))}
        </Section>
        {others.length > 0 && <Section header="Other recordings">{others.map((r) => <RecordingRow key={r.id} recording={r} />)}</Section>}
      </div>
    </div>
  );
}

export function AttemptListRow({ attempt }: { attempt: Attempt }) {
  const d = useDB();
  return (
    <div className="grow stack" style={{ ["--gap" as string]: "5px", textAlign: "left" }}>
      <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap" }}>
        <PhaseBadge attempt={attempt} />
        <span className="sub soft">{fmtDate(attempt.date)}, {fmtTime(attempt.date)}</span>
      </div>
      <div className="sub" style={{ fontWeight: 500, display: "flex", gap: 8, flexWrap: "wrap" }}>
        {attempt.tempo != null && <span className="mono">{attempt.tempo} bpm</span>}
        {attempt.errorCategory && <span>{errorInfo[attempt.errorCategory].label}</span>}
        {attempt.outcome && <span>{outcomeLabel[attempt.outcome]}</span>}
        {recordingFor(d, attempt.id) && <span aria-label="Has recording"><Icon name="wave" /></span>}
      </div>
      {!isBlank(attempt.observation) && <div className="clamp3">{attempt.observation}</div>}
      {!isBlank(attempt.nextStep) && <div className="sub soft">Next: {attempt.nextStep}</div>}
    </div>
  );
}

/** Edit an attempt after the fact. Changing it never touches other entries. */
export function AttemptEditor({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const a = d.attempts.find((x) => x.id === id);
  if (!a) return <div className="screen-body"><NavBar back /><p className="pad soft">This attempt was deleted.</p></div>;
  const set = (patch: Partial<Attempt>) => update((db) => { const x = db.attempts.find((y) => y.id === id); if (x) Object.assign(x, patch); });
  const recs = d.recordings.filter((r) => r.attemptId === id);
  const toLocal = (t: number) => { const dt = new Date(t); dt.setMinutes(dt.getMinutes() - dt.getTimezoneOffset()); return dt.toISOString().slice(0, 16); };
  return (
    <div className="screen-body">
      <NavBar back title="Attempt" trailing={
        <button className="icon-btn danger" aria-label="Delete attempt" onClick={() => {
          if (!confirm("Delete this attempt? Only this attempt is deleted; its recording stays in the Journal.")) return;
          nav.pop(); update((db) => deleteAttempt(db, id));
        }}><Icon name="trash" /></button>
      } />
      <div className="list">
        <Section footer={a.isRetest ? "This attempt completed a cold retest, so it stays cold." : undefined}>
          <div className="cell">
            <div className="seg">
              {(["cold", "afterPractice"] as AttemptPhase[]).map((p) => (
                <button key={p} className={a.phase === p ? "on" : ""} disabled={a.isRetest} onClick={() => set({ phase: p })}>{phaseLabel[p]}</button>
              ))}
            </div>
          </div>
          <label className="cell"><span className="grow">When</span>
            <input type="datetime-local" className="inline-input narrow" value={toLocal(a.date)} onChange={(e) => { const t = new Date(e.target.value).getTime(); if (Number.isFinite(t)) set({ date: t }); }} />
          </label>
        </Section>
        <Section header="How it went">
          <TempoField value={a.tempo?.toString() ?? ""} onChange={(v) => set({ tempo: parseTempo(v) })} />
          <label className="cell"><span className="grow">What got in the way</span>
            <select className="inline-select" value={a.errorCategory ?? ""} onChange={(e) => set({ errorCategory: (e.target.value || null) as ErrorCategory | null })}>
              <option value="">Nothing in particular</option>
              {errorCategories.map((c) => <option key={c} value={c}>{errorInfo[c].label}</option>)}
            </select>
          </label>
          <label className="cell"><span className="grow">Outcome</span>
            <select className="inline-select" value={a.outcome ?? ""} onChange={(e) => set({ outcome: (e.target.value || null) as Outcome | null })}>
              <option value="">Not an experiment</option>
              {outcomes.map((o) => <option key={o} value={o}>{outcomeLabel[o]}</option>)}
            </select>
          </label>
          <div className="cell"><textarea className="inline-input" rows={3} value={a.observation} onChange={(e) => set({ observation: e.target.value })} placeholder="What happened" /></div>
          {a.phase === "afterPractice" && <div className="cell"><textarea className="inline-input" rows={2} value={a.smallerExercise} onChange={(e) => set({ smallerExercise: e.target.value })} placeholder="Smaller exercise" /></div>}
          <div className="cell"><textarea className="inline-input" rows={2} value={a.nextStep} onChange={(e) => set({ nextStep: e.target.value })} placeholder="Next step" /></div>
        </Section>
        {recs.length > 0 && <Section header="Recordings">{recs.map((r) => <RecordingRow key={r.id} recording={r} />)}</Section>}
      </div>
    </div>
  );
}

export function TaskEditor({ id, skillId = null, pieceId = null }: { id?: string; skillId?: string | null; pieceId?: string | null }) {
  const d = useDB();
  const nav = useNav();
  const existing = id ? d.tasks.find((t) => t.id === id) : undefined;
  const [title, setTitle] = useState(existing?.title ?? "");
  const [context, setContext] = useState(existing?.contextNote ?? "");
  const [skill, setSkill] = useState(existing?.skillId ?? skillId ?? "");
  const [piece, setPiece] = useState(existing?.pieceId ?? pieceId ?? "");
  const save = () => {
    update((db) => {
      const t = existing ? db.tasks.find((x) => x.id === existing.id)! : newTask(title);
      t.title = title.trim(); t.contextNote = context.trim(); t.skillId = skill || null; t.pieceId = piece || null;
      if (!existing) db.tasks.push(t);
    });
    nav.closeSheet();
  };
  return (
    <div className="sheet-body">
      <SheetBar title={existing ? "Edit target" : "New target"} action={save} actionDisabled={isBlank(title)} />
      <div className="list">
        <Section footer="Make it observable: something you could check next week and get the same answer.">
          <div className="cell"><textarea className="inline-input" rows={2} autoFocus value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Target, e.g. Bars 9–12 hands together at 60" /></div>
          <div className="cell"><textarea className="inline-input" rows={2} value={context} onChange={(e) => setContext(e.target.value)} placeholder="Context: edition, fingering, which hand" /></div>
        </Section>
        <Section>
          <label className="cell"><span className="grow">Skill</span>
            <select className="inline-select" value={skill} onChange={(e) => setSkill(e.target.value)}>
              <option value="">None</option>
              {branches.map((b) => (
                <optgroup key={b} label={branchInfo[b].title}>
                  {d.skills.filter((s) => s.branch === b).map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
                </optgroup>
              ))}
            </select>
          </label>
          <label className="cell"><span className="grow">Piece</span>
            <select className="inline-select" value={piece} onChange={(e) => setPiece(e.target.value)}>
              <option value="">None</option>
              {d.pieces.map((p) => <option key={p.id} value={p.id}>{p.title}</option>)}
            </select>
          </label>
        </Section>
      </div>
    </div>
  );
}

// ---------- pieces ----------
export function PieceDetail({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const piece = d.pieces.find((p) => p.id === id);
  if (!piece) return <div className="screen-body"><NavBar back /><p className="pad soft">This piece was deleted.</p></div>;
  const tasks = d.tasks.filter((t) => t.pieceId === id).sort((a, b) => b.createdAt - a.createdAt);
  return (
    <div className="screen-body">
      <NavBar back trailing={
        <>
          <button className="icon-btn" aria-label="Edit piece" onClick={() => nav.openSheet(<PieceEditor id={id} />)}><Icon name="pencil" /></button>
          <button className="icon-btn danger" aria-label="Delete piece" onClick={() => {
            if (!confirm(`Delete “${piece.title}”? Its targets and their attempts stay; they're just no longer linked to a piece.`)) return;
            nav.pop(); update((db) => deletePiece(db, id));
          }}><Icon name="trash" /></button>
        </>
      } />
      <div className="pad stack" style={{ ["--gap" as string]: "6px" }}>
        <h1 className="display-title">{piece.title}</h1>
        {piece.composer && <p className="soft">{piece.composer}</p>}
        {piece.notes && <p>{piece.notes}</p>}
      </div>
      <div className="list">
        <Section>
          <label className="cell"><span className="grow">Show on Today</span>
            <input type="checkbox" className="switch" checked={piece.isCurrent} onChange={(e) => update((db) => { const p = db.pieces.find((x) => x.id === id); if (p) p.isCurrent = e.target.checked; })} />
          </label>
        </Section>
        <Section header="Targets">
          {!tasks.length && <div className="cell soft">Break the piece into targets: the passage that trips you, the page turn, the ending.</div>}
          {tasks.map((t) => <TaskRow key={t.id} id={t.id} />)}
          <button className="cell link-cell" onClick={() => nav.openSheet(<TaskEditor pieceId={id} />)}><Icon name="plus" />New target in this piece</button>
        </Section>
      </div>
    </div>
  );
}

export function PieceEditor({ id }: { id?: string }) {
  const d = useDB();
  const nav = useNav();
  const existing = id ? d.pieces.find((p) => p.id === id) : undefined;
  const [title, setTitle] = useState(existing?.title ?? "");
  const [composer, setComposer] = useState(existing?.composer ?? "");
  const [notes, setNotes] = useState(existing?.notes ?? "");
  const save = () => {
    update((db) => {
      if (existing) {
        const p = db.pieces.find((x) => x.id === existing.id)!;
        Object.assign(p, { title: title.trim(), composer: composer.trim(), notes: notes.trim() });
      } else {
        db.pieces.push({ id: uid(), title: title.trim(), composer: composer.trim(), notes: notes.trim(), isCurrent: true, createdAt: Date.now() });
      }
    });
    nav.closeSheet();
  };
  return (
    <div className="sheet-body">
      <SheetBar title={existing ? "Edit piece" : "Add piece"} action={save} actionDisabled={isBlank(title)} />
      <div className="list">
        <Section>
          <div className="cell"><input className="inline-input" autoFocus value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Title" /></div>
          <div className="cell"><input className="inline-input" value={composer} onChange={(e) => setComposer(e.target.value)} placeholder="Composer or artist" /></div>
          <div className="cell"><textarea className="inline-input" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Notes: edition, why you chose it" /></div>
        </Section>
      </div>
    </div>
  );
}
