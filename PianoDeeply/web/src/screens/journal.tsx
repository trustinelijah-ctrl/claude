import { useState } from "react";
import { isBlank, latestPair, tempoChange, type BeforeNow } from "../core/logic";
import { phaseLabel, stepInfo, type StepKind } from "../core/vocab";
import { deleteAttempt, deleteSession, evidencePoints, minutesText, plannedMinutes, recordingFor, update, useDB, uid, contextSummary, type Session } from "../store";
import { useNav } from "../nav";
import { Field, Icon, NavBar, PhaseBadge, PlayButton, RecordingRow, Section, SheetBar, dayHeading, fmtDate, fmtTime } from "../ui";
import { AttemptEditor, AttemptListRow, PieceDetail, TaskDetail, useActions } from "./practice";

type Filter = "all" | "cold" | "recordings" | "notes";
const filterLabel: Record<Filter, string> = { all: "Everything", cold: "Cold passes and retests", recordings: "With recordings", notes: "Notes and sessions" };

type Entry =
  | { kind: "attempt"; id: string; date: number }
  | { kind: "recording"; id: string; date: number }
  | { kind: "session"; id: string; date: number }
  | { kind: "note"; id: string; date: number }
  | { kind: "piece"; id: string; date: number };

/** Evidence, newest first. Before → Now → Next appears only when two comparable entries exist. */
export function Journal() {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const [filter, setFilter] = useState<Filter>("all");

  const entries: Entry[] = [];
  const add = (kind: Entry["kind"], id: string, date: number) => entries.push({ kind, id, date } as Entry);
  const loose = d.recordings.filter((r) => !r.attemptId);
  const ended = d.sessions.filter((s) => s.endedAt != null);
  if (filter === "all") {
    d.attempts.forEach((a) => add("attempt", a.id, a.date));
    loose.forEach((r) => add("recording", r.id, r.createdAt));
    ended.forEach((s) => add("session", s.id, s.startedAt));
    d.notes.forEach((n) => add("note", n.id, n.date));
    d.pieces.forEach((p) => add("piece", p.id, p.createdAt));
  } else if (filter === "cold") {
    d.attempts.filter((a) => a.phase === "cold").forEach((a) => add("attempt", a.id, a.date));
  } else if (filter === "recordings") {
    d.attempts.filter((a) => recordingFor(d, a.id)).forEach((a) => add("attempt", a.id, a.date));
    loose.forEach((r) => add("recording", r.id, r.createdAt));
  } else {
    ended.forEach((s) => add("session", s.id, s.startedAt));
    d.notes.forEach((n) => add("note", n.id, n.date));
  }
  entries.sort((a, b) => b.date - a.date);
  const days: { day: string; items: Entry[] }[] = [];
  for (const e of entries) {
    const label = dayHeading(e.date);
    if (days[days.length - 1]?.day === label) days[days.length - 1].items.push(e);
    else days.push({ day: label, items: [e] });
  }
  const pair = filter === "all" ? latestPair(evidencePoints(d)) : null;
  const pairTask = pair && d.tasks.find((t) => t.id === pair.taskId);

  const toolbar = (
    <>
      <button className="icon-btn" aria-label="Write a note" onClick={() => nav.openSheet(<NoteEditor />)}><Icon name="pencil" /></button>
      <label className="icon-btn" aria-label="Filter">
        <Icon name="filter" />
        <select className="overlay-select" value={filter} onChange={(e) => setFilter(e.target.value as Filter)}>
          {(Object.keys(filterLabel) as Filter[]).map((f) => <option key={f} value={f}>{filterLabel[f]}</option>)}
        </select>
      </label>
    </>
  );

  if (!entries.length && filter === "all") {
    return (
      <div className="screen-body">
        <NavBar trailing={toolbar} />
        <h1 className="large-title">Journal</h1>
        <div className="empty">
          <span style={{ fontSize: 40, color: "var(--ink-soft)" }}><Icon name="book" stroke={1.4} /></span>
          <h2 className="display-headline">Nothing here yet</h2>
          <p className="soft">Cold first passes, practice notes, retests, and recordings collect here, newest first. Nothing is added for you.</p>
          <button className="btn-primary" onClick={() => actions.planSession()}>Start practice</button>
          <button className="btn-plain" onClick={() => nav.openSheet(<NoteEditor />)}>Write a note</button>
        </div>
      </div>
    );
  }

  return (
    <div className="screen-body">
      <NavBar trailing={toolbar} />
      <h1 className="large-title">Journal</h1>
      {filter !== "all" && <p className="pad sub soft">Showing: {filterLabel[filter]} · <button className="link" onClick={() => setFilter("all")}>Show everything</button></p>}
      <div className="list">
        {pair && pairTask && (
          <Section header="Before → Now → Next"><div className="cell block"><BeforeNowCard pair={pair} title={pairTask.title} /></div></Section>
        )}
        {!entries.length && <p className="pad soft" style={{ marginTop: 16 }}>Nothing matches “{filterLabel[filter]}”.</p>}
        {days.map((day) => (
          <Section key={day.day} header={day.day}>
            {day.items.map((e) => <EntryRow key={e.kind + e.id} entry={e} />)}
          </Section>
        ))}
      </div>
    </div>
  );
}

function EntryRow({ entry }: { entry: Entry }) {
  const d = useDB();
  const nav = useNav();
  if (entry.kind === "attempt") {
    const a = d.attempts.find((x) => x.id === entry.id);
    if (!a) return null;
    const task = d.tasks.find((t) => t.id === a.taskId);
    const rec = recordingFor(d, a.id);
    return (
      <div className="cell block">
        <button className="row-button" onClick={() => nav.push(<AttemptEditor id={a.id} />)}>
          <div className="headline">{task?.title ?? "Deleted target"}</div>
          <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap", margin: "6px 0" }}>
            <PhaseBadge attempt={a} />
            {a.tempo != null && <span className="sub soft mono">{a.tempo} bpm</span>}
            <span className="sub soft">{fmtTime(a.date)}</span>
          </div>
          {task && contextSummary(d, task) && <div className="sub soft">{contextSummary(d, task)}</div>}
          {!isBlank(a.observation) && <div className="clamp3">{a.observation}</div>}
          {!isBlank(a.nextStep) && <div className="sub soft">Next: {a.nextStep}</div>}
        </button>
        <div className="row-actions">
          {rec && <PlayButton recording={rec} />}
          {task && <button className="link small-btn" onClick={() => nav.push(<TaskDetail id={task.id} />)}>Open target</button>}
          <button className="link small-btn danger" onClick={() => { if (confirm("Delete this attempt? Its recording stays.")) update((db) => deleteAttempt(db, a.id)); }}>Delete</button>
        </div>
      </div>
    );
  }
  if (entry.kind === "recording") {
    const r = d.recordings.find((x) => x.id === entry.id);
    return r ? <RecordingRow recording={r} /> : null;
  }
  if (entry.kind === "session") {
    const s = d.sessions.find((x) => x.id === entry.id);
    if (!s) return null;
    const task = d.tasks.find((t) => t.id === s.focusTaskId);
    return (
      <button className="cell nav-cell" onClick={() => nav.push(<SessionDetail id={s.id} />)}>
        <div className="grow">
          <div className="headline" style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <Icon name={s.kind === "justPlay" ? "note" : "keys"} />{s.kind === "justPlay" ? "Just played" : "Practice"} · {minutesText(s)}
          </div>
          {task && <div className="sub soft">Focus: {task.title}</div>}
          {!isBlank(s.closingEasier) && <div className="clamp3">Easier: {s.closingEasier}</div>}
          {!isBlank(s.closingNext) && <div className="sub soft">Next: {s.closingNext}</div>}
        </div>
        <Icon name="chev" />
      </button>
    );
  }
  if (entry.kind === "note") {
    const n = d.notes.find((x) => x.id === entry.id);
    if (!n) return null;
    return (
      <button className="cell nav-cell" onClick={() => nav.openSheet(<NoteEditor id={n.id} />)}>
        <span style={{ color: "var(--forest)" }}><Icon name="quote" /></span>
        <div className="grow clamp3" style={{ textAlign: "left" }}>{n.text}</div>
      </button>
    );
  }
  const p = d.pieces.find((x) => x.id === entry.id);
  return p ? (
    <button className="cell nav-cell" onClick={() => nav.push(<PieceDetail id={p.id} />)}>
      <span style={{ color: "var(--forest)" }}><Icon name="note" /></span><span className="grow">Started {p.title}</span><Icon name="chev" />
    </button>
  ) : null;
}

/** Same task, same phase, different days. The app compares your entries; it doesn't judge the playing. */
export function BeforeNowCard({ pair, title }: { pair: BeforeNow; title?: string }) {
  const d = useDB();
  const change = tempoChange(pair);
  const col = (label: string, p: BeforeNow["before"]) => {
    const rec = recordingFor(d, p.id);
    return (
      <div className="bn-col">
        <div className="headline">{label}</div>
        <div className="sub soft">{fmtDate(p.date)}</div>
        {p.tempo != null && <div className="sub mono">{p.tempo} bpm</div>}
        {!isBlank(p.observation) && <div className="sub">{p.observation}</div>}
        {rec && <PlayButton recording={rec} label={`Play ${label.toLowerCase()}`} />}
      </div>
    );
  };
  return (
    <div className="stack" style={{ ["--gap" as string]: "12px" }}>
      {title && <div className="display-headline">{title}</div>}
      <div className="sub soft">{phaseLabel[pair.phase]} compared with {phaseLabel[pair.phase].toLowerCase()}</div>
      <div className="bn-row">{col("Before", pair.before)}<span className="soft bn-arrow"><Icon name="arrow" /></span>{col("Now", pair.now)}</div>
      {change != null && change !== 0 && <div className="sub" style={{ fontWeight: 500 }}>{change > 0 ? `${change} bpm faster` : `${-change} bpm slower`}, by your own count.</div>}
      {pair.next && <div><div className="headline">Next</div><div>{pair.next}</div></div>}
    </div>
  );
}

export function NoteEditor({ id }: { id?: string }) {
  const d = useDB();
  const nav = useNav();
  const existing = id ? d.notes.find((n) => n.id === id) : undefined;
  const [text, setText] = useState(existing?.text ?? "");
  const save = () => {
    update((db) => {
      const n = existing && db.notes.find((x) => x.id === existing.id);
      if (n) n.text = text.trim();
      else db.notes.push({ id: uid(), date: Date.now(), text: text.trim() });
    });
    nav.closeSheet();
  };
  return (
    <div className="sheet-body">
      <SheetBar title={existing ? "Note" : "New note"} action={save} actionDisabled={isBlank(text)} />
      <div className="list">
        <Section>
          <div className="cell"><textarea className="inline-input" rows={8} autoFocus value={text} onChange={(e) => setText(e.target.value)} placeholder="A small discovery, a question, something you heard." /></div>
        </Section>
        {existing && (
          <div className="pad" style={{ marginTop: 16 }}>
            <button className="btn-plain danger" onClick={() => { if (confirm("Delete this note?")) { nav.closeSheet(); update((db) => { db.notes = db.notes.filter((n) => n.id !== existing.id); }); } }}>Delete note</button>
          </div>
        )}
      </div>
    </div>
  );
}

/** Read and edit a finished session's notes. */
export function SessionDetail({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const s = d.sessions.find((x) => x.id === id);
  if (!s) return <div className="screen-body"><NavBar back /><p className="pad soft">This session was deleted.</p></div>;
  const set = (patch: Partial<Session>) => update((db) => { const x = db.sessions.find((y) => y.id === id); if (x) Object.assign(x, patch); });
  const task = d.tasks.find((t) => t.id === s.focusTaskId);
  const attempts = d.attempts.filter((a) => a.sessionId === id).sort((a, b) => a.date - b.date);
  const recs = d.recordings.filter((r) => r.sessionId === id && !r.attemptId);
  const notes = Object.entries(s.stepNotes).filter(([, v]) => !isBlank(v));
  return (
    <div className="screen-body">
      <NavBar back title={s.kind === "justPlay" ? "Just play" : "Session"} trailing={
        <button className="icon-btn danger" aria-label="Delete session" onClick={() => {
          if (!confirm("Delete this session? Attempts and recordings from it stay in the Journal.")) return;
          nav.pop(); update((db) => deleteSession(db, id));
        }}><Icon name="trash" /></button>
      } />
      <div className="list">
        <Section>
          <div className="cell"><span className="grow">Date</span><span className="soft">{fmtDate(s.startedAt)}, {fmtTime(s.startedAt)}</span></div>
          <div className="cell"><span className="grow">Played</span><span className="soft">{minutesText(s)}</span></div>
          {s.kind === "practice" && <div className="cell"><span className="grow">Planned</span><span className="soft">{plannedMinutes(s)} min</span></div>}
          {task && <button className="cell nav-cell" onClick={() => nav.push(<TaskDetail id={task.id} />)}><span className="grow">Focus: {task.title}</span><Icon name="chev" /></button>}
        </Section>
        {s.kind === "practice" && (
          <>
            <div className="pad stack" style={{ ["--gap" as string]: "14px", marginTop: 22 }}>
              <Field label="Smaller exercise" value={s.smaller} onChange={(v) => set({ smaller: v })} />
              <Field label="What fixed it" value={s.correction} onChange={(v) => set({ correction: v })} />
              <Field label="Variation" value={s.variation} onChange={(v) => set({ variation: v })} />
              <Field label="Back into the music" value={s.reintegration} onChange={(v) => set({ reintegration: v })} />
              {notes.map(([k, v]) => <div key={k}><div className="headline">{stepInfo[k as StepKind]?.title ?? k}</div><div>{v}</div></div>)}
              <Field label="What got easier" value={s.closingEasier} onChange={(v) => set({ closingEasier: v })} />
              <Field label="Next time" value={s.closingNext} onChange={(v) => set({ closingNext: v })} />
            </div>
          </>
        )}
        {attempts.length > 0 && (
          <Section header="Attempts">
            {attempts.map((a) => <button key={a.id} className="cell nav-cell" onClick={() => nav.push(<AttemptEditor id={a.id} />)}><AttemptListRow attempt={a} /><Icon name="chev" /></button>)}
          </Section>
        )}
        {recs.length > 0 && <Section header="Recordings">{recs.map((r) => <RecordingRow key={r.id} recording={r} />)}</Section>}
      </div>
    </div>
  );
}

