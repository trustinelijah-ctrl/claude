// Shared UI pieces: icons, the drawn keyboard, bars, sheets, badges, fields,
// and the record/play controls.
import { useEffect, useState, type ReactNode } from "react";
import { Clock } from "./core/logic";
import type { Feedback } from "./core/vocab";
import { downloadRecording, deleteRecording, startRecording, stopRecording, togglePlay, usePlayer, useRecorder } from "./audio";
import { attemptLabel, type Attempt, type Recording } from "./store";
import { useNav } from "./nav";

const PATHS: Record<string, string> = {
  gear: "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z M12 2.5v3 M12 18.5v3 M2.5 12h3 M18.5 12h3 M5.3 5.3l2.1 2.1 M16.6 16.6l2.1 2.1 M5.3 18.7l2.1-2.1 M16.6 7.4l2.1-2.1",
  snowflake: "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9 M9.5 4.5 12 6l2.5-1.5 M9.5 19.5 12 18l2.5 1.5",
  note: "M9 17a3 3 0 1 1-3-3 3 3 0 0 1 3 3zm0 0V4l9 2.5",
  chev: "M9 5l7 7-7 7", back: "M15 5l-7 7 7 7", down: "M5 9l7 7 7-7",
  check: "M5 12.5l4.5 4.5L19 7",
  scope: "M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16z M12 1.5v5 M12 17.5v5 M1.5 12h5 M17.5 12h5",
  more: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M8 12h.01 M12 12h.01 M16 12h.01",
  pencil: "M4 20h4L19 9l-4-4L4 16z M13.5 6.5l4 4",
  filter: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M7.5 9.5h9 M9.5 12.5h5 M11 15.5h2",
  arrow: "M5 12h14 M13 6l6 6-6 6",
  keys: "M4 5h16v14H4z M9.5 13v6 M14.5 13v6 M7.5 5v8h4V5 M12.5 5v8h4V5",
  hand: "M8 13V6a1.5 1.5 0 0 1 3 0v5 M11 10.5V4.5a1.5 1.5 0 0 1 3 0V11 M14 10.5V6a1.5 1.5 0 0 1 3 0v8a6 6 0 0 1-6 6h-1a6 6 0 0 1-5-2.7L3.5 14a1.5 1.5 0 0 1 2.4-1.8L8 14",
  metronome: "M8.5 3h7l3.5 18H5z M12 17l4.5-10 M8.5 14h7",
  list: "M4 6h11 M4 11h11 M4 16h7 M19 4v11.5 M19 15.5a2.5 2.5 0 1 1-2.5-2.5",
  ear: "M7 9a5 5 0 0 1 10 0c0 3-3 4-3 7a3 3 0 0 1-6 0 M10 9a2 2 0 0 1 4 0",
  sparkles: "M11 3l1.8 5.2L18 10l-5.2 1.8L11 17l-1.8-5.2L4 10l5.2-1.8z M18.5 15l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z",
  search: "M10.5 4a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13z M15.5 15.5 21 21",
  alert: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 7.5v5.5 M12 16.5h.01",
  sun: "M3 18h18 M6.5 18a5.5 5.5 0 0 1 11 0 M12 5v2.5 M5.3 8.8l1.8 1.8 M18.7 8.8l-1.8 1.8",
  map: "M3 6.5l6-2.5 6 2.5 6-2.5v13.5l-6 2.5-6-2.5-6 2.5z M9 4v13.5 M15 6.5V20",
  book: "M4 19.5V5a2 2 0 0 1 2-2h14v15H6a2 2 0 0 0-2 2 2 2 0 0 0 2 2h14 M8 7h8",
  plus: "M12 5v14 M5 12h14",
  mic: "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z M5 11a7 7 0 0 0 14 0 M12 18v3",
  micoff: "M3 3l18 18 M9 9v3a3 3 0 0 0 5.1 2.1 M15 9.3V6a3 3 0 0 0-5.7-1.3 M5 11a7 7 0 0 0 11.8 5 M19 11a7 7 0 0 1-.6 2.8 M12 18v3",
  play: "M7 4.5v15l12-7.5z", stop: "M6 6h12v12H6z", pause: "M6.5 5h3.5v14H6.5z M14 5h3.5v14H14z",
  wave: "M4 12h1 M7 8v8 M10 5v14 M13 9v6 M16 6v12 M19 10v4",
  trash: "M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13",
  download: "M12 4v11 M7 10l5 5 5-5 M5 20h14",
  clock: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 7v5l3 2",
  quote: "M5 17c2-1 3-3 3-6H5V6h5v5c0 4-2 7-5 8z M14 17c2-1 3-3 3-6h-3V6h5v5c0 4-2 7-5 8z",
  retry: "M20 12a8 8 0 1 1-2.3-5.7 M20 4v5h-5",
  archive: "M3 5h18v4H3z M5 9v10h14V9 M10 13h4",
};

export function Icon({ name, size, stroke = 1.8, fill }: { name: string; size?: number; stroke?: number; fill?: boolean }) {
  return (
    <svg className="i" viewBox="0 0 24 24" aria-hidden="true"
      style={{ width: size ?? "1em", height: size ?? "1em", strokeWidth: stroke, fill: fill ? "currentColor" : "none" }}>
      <path d={PATHS[name] ?? ""} />
    </svg>
  );
}

// ---------- keyboard (same drawing as KeyboardView.swift) ----------
const WHITE = new Set([0, 2, 4, 5, 7, 9, 11]);
export function Keyboard({ lo, hi, marks = {}, labels = {}, height = 96, width, label }: {
  lo: number; hi: number; marks?: Record<number, "bass" | "tone">; labels?: Record<number, string>;
  height?: number; width?: number; label?: string;
}) {
  const W = width ?? 320, H = height;
  const whites: number[] = [];
  for (let m = lo; m <= hi; m++) if (WHITE.has(m % 12)) whites.push(m);
  const ww = W / whites.length, bw = ww * 0.62, bh = H * 0.6;
  const fill = (m: number, white: boolean) =>
    marks[m] === "bass" ? "var(--brass)" : marks[m] === "tone" ? "var(--forest)" : white ? "var(--white-key)" : "var(--black-key)";
  const blacks: number[] = [];
  for (let m = lo; m <= hi; m++) if (!WHITE.has(m % 12) && whites.some((w) => w < m)) blacks.push(m);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} width={width ?? "100%"} role={label ? "img" : undefined} aria-label={label}
      aria-hidden={label ? undefined : true} style={{ display: "block", maxWidth: "100%" }}>
      {whites.map((m, i) => {
        const x = i * ww + 0.75, w = ww - 1.5;
        return (
          <g key={m}>
            <path d={`M${x} 0H${x + w}V${H - 5}Q${x + w} ${H} ${x + w - 5} ${H}H${x + 5}Q${x} ${H} ${x} ${H - 5}Z`} fill={fill(m, true)} stroke="var(--key-edge)" strokeWidth={0.75} />
            {labels[m] && <text x={i * ww + ww / 2} y={H - 10} textAnchor="middle" className="key-label">{labels[m]}</text>}
          </g>
        );
      })}
      {blacks.map((m) => {
        const x = whites.filter((w) => w < m).length * ww - bw / 2;
        return (
          <g key={m}>
            <path d={`M${x} 0H${x + bw}V${bh - 3}Q${x + bw} ${bh} ${x + bw - 3} ${bh}H${x + 3}Q${x} ${bh} ${x} ${bh - 3}Z`} fill={fill(m, false)} />
            {labels[m] && <text x={x + bw / 2} y={bh - 8} textAnchor="middle" className="key-label small">{labels[m]}</text>}
          </g>
        );
      })}
    </svg>
  );
}
export const KeyboardMotif = () => <Keyboard lo={60} hi={76} height={30} width={132} />;

// ---------- bars and layout ----------
export function NavBar({ title, back, leading, trailing }: { title?: string; back?: string | boolean; leading?: ReactNode; trailing?: ReactNode }) {
  const nav = useNav();
  return (
    <header className="navbar">
      <div className="nb-side">
        {back ? (
          <button className="link nb-back" onClick={nav.pop}><Icon name="back" size={20} stroke={2.2} />{typeof back === "string" ? back : "Back"}</button>
        ) : leading}
      </div>
      <div className="nb-title">{title}</div>
      <div className="nb-side right">{trailing}</div>
    </header>
  );
}

/** Sheet chrome: Cancel · title · primary action. */
export function SheetBar({ title, onCancel, action, actionLabel = "Save", actionDisabled, cancelLabel = "Cancel" }: {
  title: string; onCancel?: () => void; action?: () => void; actionLabel?: string; actionDisabled?: boolean; cancelLabel?: string;
}) {
  const nav = useNav();
  return (
    <header className="navbar sheetbar">
      <div className="nb-side"><button className="link" onClick={onCancel ?? nav.closeSheet}>{cancelLabel}</button></div>
      <div className="nb-title">{title}</div>
      <div className="nb-side right">
        {action && <button className="link strong" onClick={action} disabled={actionDisabled}>{actionLabel}</button>}
      </div>
    </header>
  );
}

export function Section({ header, footer, children }: { header?: ReactNode; footer?: ReactNode; children: ReactNode }) {
  return (
    <section className="section">
      {header && <h3 className="sec-h">{header}</h3>}
      <div className="group">{children}</div>
      {footer && <p className="sec-f">{footer}</p>}
    </section>
  );
}

export function Chip({ label, on, onClick }: { label: string; on: boolean; onClick: () => void }) {
  return <button className={`chip ${on ? "on" : ""}`} aria-pressed={on} onClick={onClick}>{label}</button>;
}

export function PhaseBadge({ attempt }: { attempt: Pick<Attempt, "phase" | "isRetest"> }) {
  const cold = attempt.phase === "cold";
  return (
    <span className={`badge ${cold ? "cold" : "warm"}`}>
      <Icon name={cold ? "snowflake" : "retry"} />{attemptLabel(attempt as Attempt)}
    </span>
  );
}

export function StateTag({ state, text }: { state: string; text: string }) {
  const strong = ["fluent", "reliableLater", "usableFreely"].includes(state);
  return <span className={`tag ${strong ? "strong" : ""}`}>{text}</span>;
}

/** A finished experiment that worked gets a brass glow; anything else gets the words only. */
export function FeedbackBanner({ feedback }: { feedback: Feedback | null }) {
  const nav = useNav();
  if (!feedback) return null;
  return (
    <div className="feedback" role="status" onClick={() => nav.showFeedback(null)}>
      <span className={`fb-icon ${feedback.celebrate ? "celebrate" : ""}`}>
        <Icon name={feedback.celebrate ? "check" : "scope"} stroke={2.6} />
      </span>
      <span>{feedback.message}</span>
    </div>
  );
}

export function Field({ label, value, onChange, placeholder, rows = 2 }: {
  label?: string; value: string; onChange: (v: string) => void; placeholder?: string; rows?: number;
}) {
  return (
    <label className="field-block">
      {label && <span className="headline">{label}</span>}
      <textarea className="field" rows={rows} value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
    </label>
  );
}

export function TempoField({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  return (
    <label className="cell">
      <span className="grow">Tempo</span>
      <input className="inline-input num" inputMode="numeric" placeholder="optional" value={value}
        onChange={(e) => onChange(e.target.value.replace(/\D/g, "").slice(0, 3))} aria-label="Tempo in bpm" />
      <span className="soft">bpm</span>
    </label>
  );
}
export const parseTempo = (s: string) => {
  const n = parseInt(s, 10);
  return Number.isFinite(n) && n >= 10 && n <= 400 ? n : null;
};

export function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}

// ---------- recording ----------
function MicExplanation({ onContinue }: { onContinue: () => void }) {
  const nav = useNav();
  return (
    <div className="sheet-body pad stack" style={{ ["--gap" as string]: "18px", paddingTop: 28 }}>
      <span style={{ color: "var(--forest)", fontSize: 30 }}><Icon name="mic" /></span>
      <h2 className="display-title">Recording your playing</h2>
      <p>The microphone is only on while you're recording. Recordings are kept in this browser on this device; nothing is uploaded.</p>
      <p className="soft">The app can't judge notes, tone, or accuracy from audio. Recordings are for you to listen back and compare.</p>
      <button className="btn-primary" onClick={() => { nav.closeSheet(); onContinue(); }}>Continue</button>
      <button className="btn-plain" onClick={nav.closeSheet}>Not now</button>
    </div>
  );
}

/** Record button with the permission flow: explain first, then ask; if refused, say so and carry on. */
export function RecordControl({ owner, title, link, onFinished }: {
  owner: string; title: string; link: Partial<Pick<Recording, "taskId" | "attemptId" | "sessionId">>; onFinished?: (r: Recording) => void;
}) {
  const rec = useRecorder();
  const nav = useNav();
  const now = useNow();
  const mine = rec.recording && rec.ownerId === owner;
  const start = () => void startRecording(owner, title, link, onFinished);

  if (rec.permission === "unsupported") return <p className="foot soft">This browser can't record audio. Everything else works.</p>;
  if (mine) {
    return (
      <button className="btn-secondary" onClick={() => void stopRecording()}>
        <span className="rec-dot" aria-hidden="true" />Stop recording <span className="mono">{Clock.format(now - (rec.startedAt ?? now))}</span>
      </button>
    );
  }
  if (rec.recording) return <p className="foot soft">Another recording is running. Stop it first.</p>;
  if (rec.permission === "denied") {
    return (
      <div className="stack" style={{ ["--gap" as string]: "6px" }}>
        <div className="headline" style={{ display: "flex", gap: 8, alignItems: "center" }}><Icon name="micoff" />Microphone access is off</div>
        <p className="foot soft">Recording isn't available, and everything else works as usual. To turn it on, allow the microphone for this site in your browser's settings.</p>
      </div>
    );
  }
  return (
    <div className="stack" style={{ ["--gap" as string]: "6px" }}>
      <button className="btn-secondary"
        onClick={() => (rec.permission === "granted" ? start() : nav.openSheet(<MicExplanation onContinue={start} />))}>
        <Icon name="mic" />Record
      </button>
      {rec.error && <p className="foot soft">{rec.error}</p>}
    </div>
  );
}

export function PlayButton({ recording, label }: { recording: Recording; label?: string }) {
  const player = usePlayer();
  if (player.missing.has(recording.id)) {
    return <span className="foot soft" style={{ display: "inline-flex", gap: 6, alignItems: "center" }}><Icon name="alert" />Audio isn't available in this browser</span>;
  }
  const playing = player.playingId === recording.id;
  return (
    <button className="link small-btn" onClick={() => void togglePlay(recording.id)} aria-label={`${playing ? "Stop" : "Play"} ${recording.title}`}>
      <Icon name={playing ? "stop" : "play"} fill />{label ?? (playing ? "Stop" : "Play")}
    </button>
  );
}

export function RecordingRow({ recording }: { recording: Recording }) {
  const mins = Math.floor(recording.duration / 60), secs = Math.round(recording.duration % 60);
  return (
    <div className="cell block">
      <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
        <span style={{ color: "var(--forest)" }}><Icon name="wave" /></span>
        <span className="grow" style={{ fontWeight: 500 }}>{recording.title || "Recording"}</span>
        <span className="sub soft mono">{mins}:{String(secs).padStart(2, "0")}</span>
      </div>
      <div className="row-actions">
        <PlayButton recording={recording} />
        <button className="link small-btn" onClick={() => void downloadRecording(recording)}><Icon name="download" />Download</button>
        <button className="link small-btn danger" onClick={() => { if (confirm("Delete this recording? The audio is removed from this browser.")) deleteRecording(recording.id); }}>
          <Icon name="trash" />Delete
        </button>
      </div>
    </div>
  );
}

export const fmtDate = (t: number) => new Date(t).toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" });
export const fmtTime = (t: number) => new Date(t).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
export function dayHeading(t: number): string {
  const d = new Date(t), today = new Date();
  const yest = new Date(); yest.setDate(today.getDate() - 1);
  if (d.toDateString() === today.toDateString()) return "Today";
  if (d.toDateString() === yest.toDateString()) return "Yesterday";
  return d.toLocaleDateString(undefined, { weekday: "short", day: "numeric", month: "short" });
}

/** Wrapping row of chips, so they never run off screen at large text sizes. */
export const FlowRow = ({ children }: { children: ReactNode }) => <div className="chips">{children}</div>;
