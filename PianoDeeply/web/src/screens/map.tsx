import { useState } from "react";
import { DayPhrase, isBlank } from "../core/logic";
import { chordName, chordSpoken, chordTones, inversionName, keyboardRange, keys, noteName, smoothTwoFiveOne, spokenName, twoFiveOne, voicing } from "../core/chords";
import { branchInfo, branches, skillStates, stateInfo, type SkillBranch } from "../core/vocab";
import { attemptLabel, deleteSkill, toggleBottleneck, update, useDB, uid, type DB, type Skill } from "../store";
import { useNav } from "../nav";
import { Icon, Keyboard, NavBar, Section, StateTag } from "../ui";
import { TaskEditor, TaskRow, useActions } from "./practice";

const lastAttemptForSkill = (d: DB, skillId: string) => {
  const taskIds = new Set(d.tasks.filter((t) => t.skillId === skillId).map((t) => t.id));
  return d.attempts.filter((a) => a.taskId && taskIds.has(a.taskId)).sort((a, b) => b.date - a.date)[0] ?? null;
};

/** Eight branches, qualitative states, one bottleneck. No totals, no percentages. */
export function SkillMap() {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const bottleneck = d.skills.find((s) => s.isBottleneck);
  const nothingExplored = d.skills.every((s) => s.state === "notExplored");
  const last = bottleneck && lastAttemptForSkill(d, bottleneck.id);
  const lastTask = last && d.tasks.find((t) => t.id === last.taskId);
  return (
    <div className="screen-body">
      <NavBar />
      <h1 className="large-title">Map</h1>
      <div className="list">
        <Section>
          {bottleneck ? (
            <div className="cell block stack" style={{ ["--gap" as string]: "8px" }}>
              <div className="display-headline" style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <span style={{ color: "var(--brass)" }}><Icon name="alert" /></span>{bottleneck.name}
              </div>
              <div className="sub" style={{ fontWeight: 500 }}>Your current bottleneck, in {branchInfo[bottleneck.branch].title.toLowerCase()}.</div>
              {last && lastTask ? (
                <>
                  <div className="sub soft">Last time: {lastTask.title}, {DayPhrase.since(last.date, Date.now())}. {attemptLabel(last)}{isBlank(last.observation) ? "." : `: ${last.observation}`}</div>
                  <button className="btn-secondary" onClick={() => actions.planSession(lastTask.id)}>Practise it</button>
                </>
              ) : (
                <>
                  <div className="sub soft">Nothing logged for it yet. Add a target where it shows up.</div>
                  <button className="btn-secondary" onClick={() => nav.openSheet(<TaskEditor skillId={bottleneck.id} />)}>Add a target for it</button>
                </>
              )}
            </div>
          ) : (
            <div className="cell soft">
              {nothingExplored
                ? "Everything starts as Not explored and only changes when you change it. Open a branch, set where you are, and mark the one skill that's holding you back."
                : "No bottleneck marked. Open a skill and mark the one that's getting in the way most; Today will suggest work on it."}
            </div>
          )}
        </Section>
        <Section header="Branches">
          {branches.map((b) => {
            const skills = d.skills.filter((s) => s.branch === b);
            const explored = skills.filter((s) => s.state !== "notExplored");
            return (
              <button key={b} className="cell nav-cell top" onClick={() => nav.push(<BranchView branch={b} />)}>
                <span className="branch-icon"><Icon name={branchInfo[b].icon} /></span>
                <div className="grow">
                  <div style={{ fontWeight: 600 }}>{branchInfo[b].title} {skills.some((s) => s.isBottleneck) && <span style={{ color: "var(--brass)" }} aria-label="Contains your bottleneck"><Icon name="alert" /></span>}</div>
                  <div className="sub soft">{branchInfo[b].summary}</div>
                  {explored.length > 0 && <div className="chips" style={{ marginTop: 6, gap: 6 }}>{explored.map((s) => <StateTag key={s.id} state={s.state} text={s.name} />)}</div>}
                </div>
                <Icon name="chev" />
              </button>
            );
          })}
        </Section>
        <Section header="On the keyboard" footer="See each chord's notes, step through its inversions, and try the smooth voice leading.">
          <button className="cell nav-cell block" onClick={() => nav.push(<ChordExplorer />)}>
            <div style={{ fontWeight: 500, display: "flex", gap: 8, alignItems: "center", marginBottom: 10 }}><Icon name="keys" />ii–V–I in F</div>
            <Keyboard lo={53} hi={77} height={54} marks={{ 55: "bass", 58: "tone", 62: "tone", 65: "tone" }} />
          </button>
        </Section>
      </div>
    </div>
  );
}

function BranchView({ branch }: { branch: SkillBranch }) {
  const d = useDB();
  const nav = useNav();
  const skills = d.skills.filter((s) => s.branch === branch).sort((a, b) => a.sortOrder - b.sortOrder);
  const add = () => {
    const name = prompt("Name of the new subskill");
    if (!name || isBlank(name)) return;
    update((db) => {
      db.skills.push({ id: uid(), branch, name: name.trim(), evidence: "", state: "notExplored", isBottleneck: false,
        sortOrder: Math.max(-1, ...skills.map((s) => s.sortOrder)) + 1, createdAt: Date.now() });
    });
  };
  return (
    <div className="screen-body">
      <NavBar back="Map" title={branchInfo[branch].title} />
      <p className="pad soft" style={{ marginTop: 8 }}>{branchInfo[branch].summary}</p>
      <div className="list">
        <Section header="Subskills">
          {!skills.length && <div className="cell soft">No subskills here. Add the ones that matter to you.</div>}
          {skills.map((s) => {
            const last = lastAttemptForSkill(d, s.id);
            return (
              <button key={s.id} className="cell nav-cell" onClick={() => nav.push(<SkillDetail id={s.id} />)}>
                <div className="grow stack" style={{ ["--gap" as string]: "6px" }}>
                  <div style={{ fontWeight: 500 }}>{s.name} {s.isBottleneck && <span style={{ color: "var(--brass)" }} aria-label="Bottleneck"><Icon name="alert" /></span>}</div>
                  <div><StateTag state={s.state} text={stateInfo[s.state].label} /></div>
                  {last && <div className="sub soft">Last worked on {DayPhrase.since(last.date, Date.now())}</div>}
                </div>
                <Icon name="chev" />
              </button>
            );
          })}
          <button className="cell link-cell" onClick={add}><Icon name="plus" />Add subskill</button>
        </Section>
      </div>
    </div>
  );
}

function SkillDetail({ id }: { id: string }) {
  const d = useDB();
  const nav = useNav();
  const skill = d.skills.find((s) => s.id === id);
  if (!skill) return <div className="screen-body"><NavBar back /><p className="pad soft">This subskill was deleted.</p></div>;
  const set = (patch: Partial<Skill>) => update((db) => { const s = db.skills.find((x) => x.id === id); if (s) Object.assign(s, patch); });
  const tasks = d.tasks.filter((t) => t.skillId === id).sort((a, b) => b.createdAt - a.createdAt);
  return (
    <div className="screen-body">
      <NavBar back title={skill.name} trailing={
        <button className="icon-btn danger" aria-label="Delete subskill" onClick={() => {
          if (!confirm(`Delete “${skill.name}”? Targets linked to it stay.`)) return;
          nav.pop(); update((db) => deleteSkill(db, id));
        }}><Icon name="trash" /></button>
      } />
      <div className="list">
        <Section footer="Evidence is something you could check: a tempo, a recording, doing it cold.">
          <div className="cell"><input className="inline-input" value={skill.name} onChange={(e) => set({ name: e.target.value })} aria-label="Name" /></div>
          <div className="cell"><textarea className="inline-input" rows={2} value={skill.evidence} onChange={(e) => set({ evidence: e.target.value })} placeholder="What would count as evidence?" /></div>
        </Section>
        <Section header="Where you are">
          {skillStates.map((st) => (
            <button key={st} className="cell choice" aria-pressed={skill.state === st} onClick={() => set({ state: st })}>
              <div className="grow"><div>{stateInfo[st].label}</div><div className="foot soft">{stateInfo[st].meaning}</div></div>
              {skill.state === st && <span className="check"><Icon name="check" stroke={2.4} /></span>}
            </button>
          ))}
        </Section>
        <Section footer="One at a time. Today's suggestion will tell you when it's based on this.">
          <label className="cell"><span className="grow">Current bottleneck</span>
            <input type="checkbox" className="switch" checked={skill.isBottleneck} onChange={() => update((db) => toggleBottleneck(db, id))} />
          </label>
        </Section>
        <Section header="Targets">
          {tasks.map((t) => <TaskRow key={t.id} id={t.id} />)}
          <button className="cell link-cell" onClick={() => nav.openSheet(<TaskEditor skillId={id} />)}><Icon name="plus" />New target for this skill</button>
        </Section>
      </div>
    </div>
  );
}

/** ii–V–I with correct spelling, drawn on a keyboard, with inversion controls. Theory is tested in core. */
export function ChordExplorer() {
  const [keyIndex, setKeyIndex] = useState(0);
  const [inversions, setInversions] = useState([0, 0, 0]);
  const key = keys[keyIndex];
  const chords = twoFiveOne(key);
  const smooth = inversions.join() === smoothTwoFiveOne.join();
  return (
    <div className="screen-body">
      <NavBar back="Map" title="Chords" />
      <div className="pad stack" style={{ ["--gap" as string]: "20px", paddingBottom: 32 }}>
        <div className="stack" style={{ ["--gap" as string]: "8px" }}>
          <h1 className="display-title">ii–V–I in {noteName(key)}</h1>
          <p className="sub soft">You'll find it all over jazz standards and plenty of pop. Brass marks the lowest note.</p>
        </div>
        <div className="seg" role="radiogroup" aria-label="Key">
          {keys.map((k, i) => <button key={i} role="radio" aria-checked={i === keyIndex} className={i === keyIndex ? "on" : ""} onClick={() => setKeyIndex(i)}>{noteName(k)}</button>)}
        </div>
        {chords.map((chord, ci) => {
          const v = voicing(chord, inversions[ci]);
          return (
            <div key={ci} className="surface stack" style={{ ["--gap" as string]: "12px" }}>
              <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
                <span className="roman">{chord.fn}</span><span className="display-headline">{chordName(chord)}</span>
                <span className="sub soft" style={{ marginLeft: "auto" }}>{inversionName(inversions[ci])}</span>
              </div>
              <Keyboard lo={keyboardRange[0]} hi={keyboardRange[1]} height={96}
                marks={Object.fromEntries(v.map((n, i) => [n.midi, i === 0 ? "bass" : "tone"]))}
                labels={Object.fromEntries(v.map((n) => [n.midi, noteName(n.name)]))}
                label={`${chordSpoken(chord)}, ${inversionName(inversions[ci])}. From the bottom: ${v.map((n) => spokenName(n.name)).join(", ")}.`} />
              <div className="sub soft">Notes: {chordTones(chord).map(noteName).join(" – ")}</div>
              <div className="seg" role="radiogroup" aria-label={`${chordName(chord)} inversion`}>
                {["Root", "1st", "2nd", "3rd"].map((l, i) => (
                  <button key={i} role="radio" aria-checked={inversions[ci] === i} className={inversions[ci] === i ? "on" : ""}
                    onClick={() => setInversions(inversions.map((x, j) => (j === ci ? i : x)))}>{l}</button>
                ))}
              </div>
            </div>
          );
        })}
        <button className="btn-secondary" disabled={smooth} onClick={() => setInversions([...smoothTwoFiveOne])}>
          {smooth ? "Showing smooth voice leading" : "Show smooth voice leading"}
        </button>
        <p className="sub soft">ii in root position, V in second inversion, I in root position. Each note moves a step or less, or stays put.</p>
        {!smooth && inversions.some((x) => x !== 0) && <button className="btn-plain" onClick={() => setInversions([0, 0, 0])}>Back to root position</button>}
      </div>
    </div>
  );
}
