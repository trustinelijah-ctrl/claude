import { useEffect, useState } from "react";
import { Clock, DayPhrase, isBlank } from "../core/logic";
import { errorInfo, stepInfo } from "../core/vocab";
import { keepAwake, stopIfOwnedBy } from "../audio";
import { deleteSession, getDB, minutesText, newTask, pendingRetests, plannedMinutes, update, useDB, type Session } from "../store";
import { useNav } from "../nav";
import { Field, Icon, KeyboardMotif, RecordControl, useNow } from "../ui";
import { AttemptSummary, LogAttempt, RetestPicker } from "./practice";

const setSession = (id: string, patch: (s: Session) => void) =>
  update((d) => { const s = d.sessions.find((x) => x.id === id); if (s) patch(s); });

/**
 * The running session. Minimizing, switching tabs, or reloading the page
 * doesn't stop or lose it: time comes from stored timestamps and every field
 * saves as you type.
 */
export function ActiveSession({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const session = d.sessions.find((s) => s.id === id);
  const owner = `session-${id}`;

  useEffect(() => {
    void keepAwake(true);
    return () => { void keepAwake(false); void stopIfOwnedBy(owner); };
  }, [owner]);

  if (!session) return null;
  if (session.endedAt != null) return <Summary session={session} />;

  const step = session.plan[session.currentStep];
  const isLast = session.currentStep >= session.plan.length - 1;
  const finish = async () => {
    await stopIfOwnedBy(owner);
    setSession(id, (s) => { s.clock = Clock.pause(s.clock, Date.now()); s.endedAt = Date.now(); });
  };
  const discard = () => {
    if (!confirm("Discard this session? The session and its notes are deleted. Attempts and recordings you logged stay in the Journal.")) return;
    void stopIfOwnedBy(owner);
    nav.closeCover();
    update((db) => deleteSession(db, id));
  };

  return (
    <div className="cover-body">
      <header className="navbar">
        <div className="nb-side"><button className="icon-btn" aria-label="Minimize. The session keeps running." onClick={nav.closeCover}><Icon name="down" size={22} stroke={2.2} /></button></div>
        <div className="nb-title" />
        <div className="nb-side right">
          <button className="link" onClick={() => void finish()}>Finish</button>
          <button className="icon-btn danger" aria-label="Discard session" onClick={discard}><Icon name="trash" /></button>
        </div>
      </header>
      <div className="pad stack" style={{ ["--gap" as string]: "26px", paddingBottom: 40 }}>
        <TimerHeader session={session} />
        <div className="step-strip" role="tablist" aria-label="Steps">
          {session.plan.map((p, i) => (
            <button key={i} role="tab" aria-selected={i === session.currentStep} className={`chip ${i === session.currentStep ? "on" : ""}`}
              onClick={() => setSession(id, (s) => { s.currentStep = i; })}>{stepInfo[p.kind].title}</button>
          ))}
        </div>
        <PlanHint session={session} />
        {step ? (
          <div className="stack" style={{ ["--gap" as string]: "16px" }}>
            <div className="stack" style={{ ["--gap" as string]: "6px" }}>
              <h2 className="display-title" style={{ display: "flex", gap: 10, alignItems: "center" }}><Icon name={stepInfo[step.kind].icon} />{stepInfo[step.kind].title}</h2>
              <p className="soft">{stepInfo[step.kind].prompt} About {step.minutes} min.</p>
            </div>
            {step.kind === "focus" ? <FocusPanel session={session} />
              : step.kind === "closing" ? <Closing session={session} />
              : <Field value={session.stepNotes[step.kind] ?? ""} placeholder="Notes (optional)"
                  onChange={(v) => setSession(id, (s) => { s.stepNotes[step.kind] = v; })} />}
          </div>
        ) : <Closing session={session} />}
        {isLast
          ? <button className="btn-primary" onClick={() => void finish()}>Finish session</button>
          : <button className="btn-primary" onClick={() => setSession(id, (s) => { s.currentStep += 1; })}>Next: {stepInfo[session.plan[session.currentStep + 1].kind].title}</button>}
        <div className="stack" style={{ ["--gap" as string]: "8px" }}>
          <div className="headline">Record</div>
          <RecordControl owner={owner} title={`Session, ${new Date(session.startedAt).toLocaleDateString()}`}
            link={{ sessionId: id, taskId: session.focusTaskId }} />
        </div>
      </div>
    </div>
  );
}

function TimerHeader({ session }: { session: Session }) {
  const now = useNow();
  const paused = session.clock.runningSince == null;
  const toggle = () => setSession(session.id, (s) => { s.clock = paused ? Clock.resume(s.clock, Date.now()) : Clock.pause(s.clock, Date.now()); });
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16 }}>
      <div aria-live="off">
        <div className={`timer ${paused ? "soft" : ""}`}>{Clock.format(Clock.elapsed(session.clock, now))}</div>
        <div className="sub soft">{paused ? "Paused" : `of ${plannedMinutes(session)} min planned`}</div>
      </div>
      <button className="round-btn" onClick={toggle} aria-label={paused ? "Resume" : "Pause"}>
        <Icon name={paused ? "play" : "pause"} fill size={24} />
      </button>
    </div>
  );
}

/** A quiet line when the clock has moved past your step. It never moves you. */
function PlanHint({ session }: { session: Session }) {
  const now = useNow(30_000);
  const i = Clock.stepIndex(Clock.elapsed(session.clock, now), session.plan);
  if (i == null || i <= session.currentStep || session.clock.runningSince == null) return null;
  return (
    <p className="sub soft" style={{ display: "flex", gap: 8, alignItems: "center" }}>
      <Icon name="clock" />By the plan's clock you'd be on {stepInfo[session.plan[i].kind].title.toLowerCase()}. Move on whenever you're ready.
    </p>
  );
}

/** Target, cold try, diagnosis, smaller, fix, vary, back into music, retest. Any part can be skipped. */
function FocusPanel({ session }: { session: Session }) {
  const d = useDB();
  const nav = useNav();
  const [newTarget, setNewTarget] = useState("");
  const task = d.tasks.find((t) => t.id === session.focusTaskId);
  const mine = d.attempts.filter((a) => a.sessionId === session.id && a.taskId === task?.id).sort((a, b) => a.date - b.date);
  const cold = mine.find((a) => a.phase === "cold");
  const practised = mine.filter((a) => a.phase === "afterPractice");
  const set = (patch: (s: Session) => void) => setSession(session.id, patch);

  if (!task) {
    const existing = d.tasks.filter((t) => !t.isArchived).slice(-12).reverse();
    return (
      <div className="stack">
        <p className="soft">Pick one thing that doesn't work yet. Make it something you could check: a passage, a hand, a tempo.</p>
        <textarea className="field" rows={2} value={newTarget} onChange={(e) => setNewTarget(e.target.value)} placeholder="e.g. Bars 9–12, hands together, no stops" />
        <button className="btn-secondary" disabled={isBlank(newTarget)} onClick={() => update((db) => {
          const t = newTask(newTarget); db.tasks.push(t);
          const s = db.sessions.find((x) => x.id === session.id); if (s) s.focusTaskId = t.id;
        })}>Set target</button>
        {existing.length > 0 && (
          <label className="field-block">
            <span className="sub soft">Or choose an existing target</span>
            <select className="field" value="" onChange={(e) => e.target.value && set((s) => { s.focusTaskId = e.target.value; })}>
              <option value="">Choose…</option>
              {existing.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}
            </select>
          </label>
        )}
      </div>
    );
  }

  return (
    <div className="stack" style={{ ["--gap" as string]: "24px" }}>
      <div className="surface"><div className="display-headline">{task.title}</div>{task.contextNote && <div className="soft">{task.contextNote}</div>}</div>
      <div className="stack" style={{ ["--gap" as string]: "10px" }}>
        <div className="headline">Try it cold</div>
        {cold ? <AttemptSummary attempt={cold} /> : (
          <>
            <p className="sub soft">Once through, before any practice on it. Note what happened.</p>
            <button className="btn-secondary" onClick={() => nav.openSheet(<LogAttempt taskId={task.id} phase="cold" sessionId={session.id} />)}>Log cold first pass</button>
          </>
        )}
      </div>
      {cold?.errorCategory && (
        <div className="stack" style={{ ["--gap" as string]: "6px" }}>
          <div className="headline">What got in the way</div>
          <div>{errorInfo[cold.errorCategory].label}</div>
          <div className="sub soft">{errorInfo[cold.errorCategory].shrink}</div>
        </div>
      )}
      <Field label="Make it smaller" value={session.smaller} onChange={(v) => set((s) => { s.smaller = v; })}
        placeholder={cold?.errorCategory ? errorInfo[cold.errorCategory].shrink : "Fewer notes, one hand, slower, or just the join."} />
      <Field label="What fixed it" value={session.correction} onChange={(v) => set((s) => { s.correction = v; })}
        placeholder="The fingering, the count, the movement that made it work." />
      <Field label="Vary it" value={session.variation} onChange={(v) => set((s) => { s.variation = v; })}
        placeholder="Change one thing: rhythm, tempo, dynamics, hands, register." />
      <div className="stack" style={{ ["--gap" as string]: "10px" }}>
        <Field label="Back into the music" value={session.reintegration} onChange={(v) => set((s) => { s.reintegration = v; })}
          placeholder="Play it with the bars around it. What happened?" />
        {practised.map((a) => <AttemptSummary key={a.id} attempt={a} />)}
        <button className="btn-secondary" onClick={() => nav.openSheet(<LogAttempt taskId={task.id} phase="afterPractice" sessionId={session.id} smaller={session.smaller} />)}>
          {practised.length ? "Log another attempt" : "Log attempt after practice"}
        </button>
      </div>
      <div className="stack" style={{ ["--gap" as string]: "8px" }}>
        <div className="headline">Test it later, cold</div>
        <p className="sub soft">Today's version is the warmed-up one. A retest shows whether it stuck.</p>
        <RetestPicker taskId={task.id} />
      </div>
    </div>
  );
}

function Closing({ session }: { session: Session }) {
  return (
    <div className="stack" style={{ ["--gap" as string]: "14px" }}>
      <Field label="What's a little easier than when you started?" placeholder="Even one bar counts." value={session.closingEasier}
        onChange={(v) => setSession(session.id, (s) => { s.closingEasier = v; })} />
      <Field label="Next time, start with…" placeholder="The first thing to try." value={session.closingNext}
        onChange={(v) => setSession(session.id, (s) => { s.closingNext = v; })} />
    </div>
  );
}

/** What got easier (your words, or experiments that worked) and one next step. */
function Summary({ session }: { session: Session }) {
  const d = getDB();
  const nav = useNav();
  const worked = d.attempts.filter((a) => a.sessionId === session.id && a.outcome === "worked");
  const task = d.tasks.find((t) => t.id === session.focusTaskId);
  const retest = task ? pendingRetests(d, task.id)[0] : undefined;
  const lastNext = d.attempts.filter((a) => a.sessionId === session.id && !isBlank(a.nextStep)).sort((a, b) => b.date - a.date)[0];
  const next = !isBlank(session.closingNext) ? session.closingNext.trim()
    : task && retest ? `Cold retest of “${task.title}” ${DayPhrase.until(retest.dueDate, Date.now())}.`
    : lastNext?.nextStep.trim() ?? null;
  return (
    <div className="cover-body pad stack" style={{ ["--gap" as string]: "28px", paddingTop: 56, paddingBottom: 40 }}>
      <div className="stack" style={{ ["--gap" as string]: "8px" }}>
        <h1 className="display">Saved.</h1>
        <p className="title3 soft">{minutesText(session)} of practice, in the Journal now.</p>
      </div>
      {(!isBlank(session.closingEasier) || worked.length > 0) && (
        <div className="surface stack" style={{ ["--gap" as string]: "10px" }}>
          <h2 className="display-headline">What got easier</h2>
          {!isBlank(session.closingEasier) && <p>{session.closingEasier.trim()}</p>}
          {worked.map((a) => (
            <p key={a.id} style={{ display: "flex", gap: 8 }}>
              <span style={{ color: "var(--forest)" }}><Icon name="check" stroke={2.4} /></span>
              {[d.tasks.find((t) => t.id === a.taskId)?.title, a.tempo != null ? `${a.tempo} bpm` : null].filter(Boolean).join(" at ")}
            </p>
          ))}
        </div>
      )}
      {next && <div className="surface stack" style={{ ["--gap" as string]: "8px" }}><h2 className="display-headline">Next</h2><p>{next}</p></div>}
      <button className="btn-primary" onClick={nav.closeCover}>Done</button>
    </div>
  );
}

/** Opening the piano: no goals, no errors, no prompts. Timer and recording only if wanted. */
export function JustPlay({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const now = useNow();
  const session = d.sessions.find((s) => s.id === id);
  const owner = `justplay-${id}`;
  useEffect(() => {
    void keepAwake(true);
    return () => { void keepAwake(false); void stopIfOwnedBy(owner); };
  }, [owner]);
  if (!session) return null;
  const showTimer = d.settings.justPlayShowsTimer;
  const done = async () => {
    await stopIfOwnedBy(owner);
    setSession(id, (s) => { s.clock = Clock.pause(s.clock, Date.now()); s.endedAt = Date.now(); });
    nav.closeCover();
  };
  return (
    <div className="cover-body pad" style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 32, textAlign: "center", paddingTop: 96, paddingBottom: 40 }}>
      <KeyboardMotif />
      <div className="stack" style={{ ["--gap" as string]: "12px" }}>
        <h1 className="display">Just play.</h1>
        <p className="title3 soft">Nothing to get right. Close this when you're done.</p>
      </div>
      {showTimer && <div className="timer soft small">{Clock.format(Clock.elapsed(session.clock, now))}</div>}
      <div className="stack" style={{ width: "100%", maxWidth: 420, textAlign: "left" }}>
        <label className="toggle-row">
          <span>Show timer</span>
          <input type="checkbox" className="switch" checked={showTimer} onChange={(e) => update((db) => { db.settings.justPlayShowsTimer = e.target.checked; })} />
        </label>
        <RecordControl owner={owner} title={`Just play, ${new Date(session.startedAt).toLocaleString(undefined, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}`} link={{ sessionId: id }} />
      </div>
      <button className="btn-primary" style={{ width: "100%", maxWidth: 420 }} onClick={() => void done()}>Done</button>
      <button className="btn-plain" onClick={nav.closeCover}>Minimize</button>
    </div>
  );
}
