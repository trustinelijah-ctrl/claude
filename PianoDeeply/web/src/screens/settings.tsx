import { useRef, useState } from "react";
import { rulesDescription } from "../core/logic";
import { deleteBlob, useRecorder } from "../audio";
import { downloadExport } from "../exporter";
import { emptyDB, getDB, getSaveError, replaceAll, update, useDB } from "../store";
import { useNav } from "../nav";
import { Section, SheetBar } from "../ui";
import { Inventory } from "./inventory";

export function Settings() {
  const d = useDB();
  const nav = useNav();
  const rec = useRecorder();
  const [confirmText, setConfirmText] = useState("");
  const resetRef = useRef<HTMLDivElement>(null);
  const mic = { granted: "Allowed", denied: "Off", undetermined: "Not asked yet", unsupported: "Not supported in this browser" }[rec.permission];
  const counts = `${d.tasks.length} targets, ${d.attempts.length} attempts, ${d.sessions.length} sessions, ${d.recordings.length} recordings, ${d.notes.length} notes`;
  const saveError = getSaveError();

  const eraseEverything = () => {
    getDB().recordings.forEach((r) => void deleteBlob(r.id));
    const fresh = emptyDB();
    fresh.settings.hasSeenWelcome = true;
    replaceAll(fresh);
    setConfirmText("");
  };

  return (
    <div className="sheet-body">
      <SheetBar title="Settings" cancelLabel="Done" />
      <div className="list">
        {saveError && <Section><div className="cell" style={{ color: "var(--brass)" }}>{saveError}</div></Section>}
        <Section>
          <button className="cell link-cell" onClick={() => { update((db) => { db.settings.inventoryHidden = false; }); nav.closeSheet(); nav.openSheet(<Inventory />); }}>
            Open the six-sample inventory
          </button>
        </Section>
        <Section header="Your data" footer="Everything you log is saved in this browser on this device: no account, no server, no analytics. Clearing your browser's site data removes it, so export a copy now and then. Audio isn't inside the JSON; download recordings from the Journal.">
          <div className="cell soft sub">{counts}</div>
          <button className="cell link-cell" onClick={() => downloadExport(getDB())}>Export as JSON</button>
        </Section>
        <Section header="Microphone" footer="Only used while you're recording. Recordings are for listening back; the app doesn't grade them.">
          <div className="cell"><span className="grow">Microphone</span><span className="soft">{mic}</span></div>
        </Section>
        <Section header="Reminders" footer="A web page can't reliably remind you when it's closed, so reminders aren't offered here. The iPhone app has optional ones that never mention missed days.">
          <div className="cell soft">Not available on the web</div>
        </Section>
        <Section header="How Today's suggestion works" footer="Checked in this order; the first rule that applies wins, and the suggestion always says which one. Plain rules, no AI.">
          {rulesDescription.map((r, i) => (
            <div key={i} className="cell top"><span className="soft mono">{i + 1}.</span><span className="grow">{r}</span></div>
          ))}
        </Section>
        <div ref={resetRef}>
          <Section header="Start over" footer="Deletes every target, attempt, session, note and recording in this browser. Type DELETE to confirm.">
            <div className="cell"><input className="inline-input" value={confirmText} onChange={(e) => setConfirmText(e.target.value)} placeholder="Type DELETE" aria-label="Type DELETE to confirm" /></div>
            <button className="cell link-cell danger" disabled={confirmText !== "DELETE"} onClick={eraseEverything}>Delete all data</button>
          </Section>
        </div>
      </div>
    </div>
  );
}
