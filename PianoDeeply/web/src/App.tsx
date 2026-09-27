import { useEffect, type ReactElement } from "react";
import { Clock } from "./core/logic";
import { getDB, useDB } from "./store";
import { NavProvider, useNav, type NavState, type Tab } from "./nav";
import { FeedbackBanner, Icon, useNow } from "./ui";
import { Today } from "./screens/today";
import { PracticeHome, runningSession, useActions } from "./screens/practice";
import { SkillMap } from "./screens/map";
import { Journal } from "./screens/journal";
import { Welcome } from "./screens/inventory";

const roots: Record<Tab, () => ReactElement> = {
  today: () => <Today />, practice: () => <PracticeHome />, map: () => <SkillMap />, journal: () => <Journal />,
};
const tabs: [Tab, string, string][] = [["today", "Today", "sun"], ["practice", "Practice", "keys"], ["map", "Map", "map"], ["journal", "Journal", "book"]];

export function App() {
  return <NavProvider render={(s) => <Shell state={s} />} />;
}

function Shell({ state }: { state: NavState }) {
  const nav = useNav();
  useEffect(() => {
    if (!getDB().settings.hasSeenWelcome) nav.openCover(<Welcome />);
  }, [nav]);

  // Lock the page behind covers and sheets.
  const overlay = !!state.cover || state.sheets.length > 0;
  useEffect(() => { document.body.style.overflow = overlay ? "hidden" : ""; }, [overlay]);

  const stack = state.stacks[state.tab];
  const current = stack.length ? stack[stack.length - 1] : roots[state.tab]();
  return (
    <div className="app">
      <main className="tab-content" key={`${state.tab}-${stack.length}`} aria-hidden={overlay}>{current}</main>
      <ActiveSessionBar />
      <nav className="tabbar" aria-label="Sections" aria-hidden={overlay}>
        {tabs.map(([t, label, icon]) => (
          <button key={t} className={`tab ${state.tab === t ? "on" : ""}`} aria-current={state.tab === t ? "page" : undefined} onClick={() => nav.setTab(t)}>
            <Icon name={icon} size={26} stroke={state.tab === t ? 2.1 : 1.7} /><span>{label}</span>
          </button>
        ))}
      </nav>
      {state.cover && <div className="layer cover" role="dialog" aria-modal="true">{state.cover}</div>}
      {state.sheets.map((sheet, i) => (
        <div key={i} className="layer sheet-layer" role="dialog" aria-modal="true" onClick={(e) => { if (e.target === e.currentTarget) nav.closeSheet(); }}>
          <div className="sheet">{sheet}</div>
        </div>
      ))}
      <div className="feedback-layer"><FeedbackBanner feedback={state.feedback} /></div>
    </div>
  );
}

/** Above the tab bar while a session is running or paused, so leaving it never loses it. */
function ActiveSessionBar() {
  const d = useDB();
  const actions = useActions();
  const now = useNow();
  const s = runningSession(d);
  if (!s) return null;
  const paused = s.clock.runningSince == null;
  return (
    <button className="session-bar" onClick={() => actions.open(s)}>
      <Icon name={paused ? "pause" : "wave"} size={22} fill={paused} />
      <span className="grow">
        <span className="block" style={{ fontWeight: 600 }}>{s.kind === "justPlay" ? "Just playing" : "Session in progress"}</span>
        <span className="block mono">{paused ? "Paused at " : ""}{Clock.format(Clock.elapsed(s.clock, now))}</span>
      </span>
      <span style={{ fontWeight: 600 }}>Return</span>
    </button>
  );
}
