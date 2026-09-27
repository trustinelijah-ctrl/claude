import { useState } from "react";
import { isBlank } from "../core/logic";
import { branchInfo, inventoryInfo, inventorySamples, type InventorySample } from "../core/vocab";
import { stopIfOwnedBy } from "../audio";
import { lastColdAttempt, newAttempt, newTask, retestContext, scheduleRetest, update, useDB, type Recording } from "../store";
import { useNav } from "../nav";
import { Icon, KeyboardMotif, PhaseBadge, RecordControl, RecordingRow, Section, SheetBar, TempoField, dayHeading, fmtDate, parseTempo } from "../ui";

/** First visit: explains the six-sample inventory and lets you skip it. */
export function Welcome() {
  const nav = useNav();
  const finish = (start: boolean) => {
    update((d) => { d.settings.hasSeenWelcome = true; });
    nav.closeCover();
    if (start) nav.openSheet(<Inventory />);
  };
  return (
    <div className="cover-body pad stack" style={{ ["--gap" as string]: "26px", paddingTop: 48, paddingBottom: 40 }}>
      <KeyboardMotif />
      <div className="stack" style={{ ["--gap" as string]: "12px" }}>
        <h1 className="display">Piano, Deeply</h1>
        <p className="title3 soft">Decide what to play, work on one thing properly, and keep a record that shows it getting easier.</p>
      </div>
      <div className="stack" style={{ ["--gap" as string]: "12px" }}>
        <h2 className="display-headline">Start with a six-sample inventory</h2>
        <p>Play six short things cold, about fifteen minutes in all. Nothing is scored. Four weeks later you play the same six again and listen to the difference.</p>
        <ul className="plain-list">
          {inventorySamples.map((s) => (
            <li key={s}><span style={{ color: "var(--forest)" }}><Icon name={branchInfo[inventoryInfo[s].branch].icon} /></span>{inventoryInfo[s].title}</li>
          ))}
        </ul>
      </div>
      <div>
        <button className="btn-primary" onClick={() => finish(true)}>Start the inventory</button>
        <button className="btn-plain" style={{ marginTop: 6 }} onClick={() => finish(false)}>I'll do this later</button>
      </div>
      <p className="foot soft">Everything you log stays in this browser on this device. There's no account.</p>
    </div>
  );
}

/** Each sample is a cold attempt on its own task, with a cold retest four weeks out. */
export function Inventory() {
  const d = useDB();
  const nav = useNav();
  const [open, setOpen] = useState<InventorySample | null>(null);
  if (open) return <SampleView sample={open} onBack={() => setOpen(null)} />;
  return (
    <div className="sheet-body">
      <SheetBar title="Inventory" cancelLabel="Done" onCancel={nav.closeSheet} />
      <div className="list">
        <Section footer="Each sample gets a cold retest four weeks after you log it. You can skip any of them.">
          {inventorySamples.map((s) => {
            const task = d.tasks.find((t) => t.inventorySample === s);
            const cold = task && lastColdAttempt(d, task.id);
            return (
              <button key={s} className="cell nav-cell" onClick={() => setOpen(s)}>
                <span className="branch-icon" style={{ color: cold ? "var(--forest)" : "var(--ink-soft)" }}>
                  <Icon name={cold ? "check" : branchInfo[inventoryInfo[s].branch].icon} stroke={cold ? 2.4 : 1.8} />
                </span>
                <div className="grow">
                  <div style={{ fontWeight: 500 }}>{inventoryInfo[s].title}</div>
                  <div className="sub soft">{cold ? `Logged ${dayHeading(cold.date).toLowerCase()}` : "Not yet"}</div>
                </div>
                <span><Icon name="chev" /></span>
              </button>
            );
          })}
        </Section>
      </div>
    </div>
  );
}

function SampleView({ sample, onBack }: { sample: InventorySample; onBack: () => void }) {
  const d = useDB();
  const info = inventoryInfo[sample];
  const task = d.tasks.find((t) => t.inventorySample === sample);
  const first = task && lastColdAttempt(d, task.id);
  const [what, setWhat] = useState("");
  const [tempo, setTempo] = useState("");
  const [observation, setObservation] = useState("");
  const [next, setNext] = useState("");
  const [take, setTake] = useState<Recording | null>(null);
  const owner = `inventory-${sample}`;

  const back = () => { void stopIfOwnedBy(owner); onBack(); };
  const save = async () => {
    const finished = (await stopIfOwnedBy(owner)) ?? take;
    update((db) => {
      let t = db.tasks.find((x) => x.inventorySample === sample);
      if (!t) { t = newTask(info.taskTitle, { inventorySample: sample }); db.tasks.push(t); }
      if (!isBlank(what) && isBlank(t.contextNote)) t.contextNote = what.trim();
      const a = newAttempt(t.id, "cold", { tempo: parseTempo(tempo), observation: observation.trim(), nextStep: next.trim() });
      db.attempts.push(a);
      const rec = finished && db.recordings.find((r) => r.id === finished.id);
      if (rec) { rec.attemptId = a.id; rec.taskId = t.id; }
      scheduleRetest(db, t.id, 28, "Four-week inventory check. " + retestContext(a), a.date);
    });
    onBack();
  };

  return (
    <div className="sheet-body">
      <SheetBar title={info.title} cancelLabel="Back" onCancel={back} action={() => void save()} />
      <div className="list">
        <Section><div className="cell">{info.instruction}</div></Section>
        {first && (
          <Section header="Already logged">
            <div className="cell block stack" style={{ ["--gap" as string]: "6px" }}>
              <PhaseBadge attempt={first} />
              <div className="sub soft">{fmtDate(first.date)}</div>
              {!isBlank(first.observation) && <div>{first.observation}</div>}
            </div>
          </Section>
        )}
        <Section header="Record it (optional)">
          <div className="cell block"><RecordControl owner={owner} title={`Inventory: ${info.title}`} link={{ taskId: task?.id ?? null }} onFinished={setTake} /></div>
          {take && d.recordings.some((r) => r.id === take.id) && <RecordingRow recording={take} />}
        </Section>
        <Section header="What you played">
          {info.prompt && <div className="cell"><input className="inline-input" value={what} onChange={(e) => setWhat(e.target.value)} placeholder={info.prompt} /></div>}
          <TempoField value={tempo} onChange={setTempo} />
          <div className="cell"><textarea className="inline-input" rows={3} value={observation} onChange={(e) => setObservation(e.target.value)} placeholder="What did you notice?" /></div>
          <div className="cell"><textarea className="inline-input" rows={2} value={next} onChange={(e) => setNext(e.target.value)} placeholder="Anything to try next? (optional)" /></div>
        </Section>
        <div className="pad" style={{ marginTop: 20 }}>
          <button className="btn-primary" onClick={() => void save()}>{first ? "Save another cold pass" : "Save sample"}</button>
        </div>
      </div>
    </div>
  );
}
