// Navigation: four tabs, each with its own push stack, plus a full-screen
// cover (session, Just play, welcome) and a stack of sheets on top.
import { createContext, useCallback, useContext, useMemo, useState, type ReactElement, type ReactNode } from "react";
import type { Feedback } from "./core/vocab";

export type Tab = "today" | "practice" | "map" | "journal";

interface NavAPI {
  tab: Tab;
  setTab: (t: Tab) => void;
  push: (el: ReactElement) => void;
  pop: () => void;
  openSheet: (el: ReactElement) => void;
  closeSheet: () => void;
  openCover: (el: ReactElement) => void;
  closeCover: () => void;
  showFeedback: (f: Feedback | null) => void;
}

const NavContext = createContext<NavAPI | null>(null);
export const useNav = () => {
  const nav = useContext(NavContext);
  if (!nav) throw new Error("useNav outside NavProvider");
  return nav;
};

export interface NavState {
  tab: Tab;
  stacks: Record<Tab, ReactElement[]>;
  sheets: ReactElement[];
  cover: ReactElement | null;
  feedback: Feedback | null;
}

export function NavProvider({ render }: { render: (s: NavState) => ReactNode }) {
  const [state, setState] = useState<NavState>({
    tab: "today", stacks: { today: [], practice: [], map: [], journal: [] }, sheets: [], cover: null, feedback: null,
  });

  const setTab = useCallback((t: Tab) => setState((s) => (
    // Tapping the tab you're on goes back to its first screen.
    s.tab === t ? { ...s, stacks: { ...s.stacks, [t]: [] } } : { ...s, tab: t }
  )), []);
  const push = useCallback((el: ReactElement) => {
    window.scrollTo(0, 0);
    setState((s) => ({ ...s, stacks: { ...s.stacks, [s.tab]: [...s.stacks[s.tab], el] } }));
  }, []);
  const pop = useCallback(() => setState((s) => ({ ...s, stacks: { ...s.stacks, [s.tab]: s.stacks[s.tab].slice(0, -1) } })), []);
  const openSheet = useCallback((el: ReactElement) => setState((s) => ({ ...s, sheets: [...s.sheets, el] })), []);
  const closeSheet = useCallback(() => setState((s) => ({ ...s, sheets: s.sheets.slice(0, -1) })), []);
  const openCover = useCallback((el: ReactElement) => setState((s) => ({ ...s, cover: el, sheets: [] })), []);
  const closeCover = useCallback(() => setState((s) => ({ ...s, cover: null })), []);
  const showFeedback = useCallback((f: Feedback | null) => {
    setState((s) => ({ ...s, feedback: f }));
    if (f) setTimeout(() => setState((s) => (s.feedback === f ? { ...s, feedback: null } : s)), 5000);
  }, []);

  const api = useMemo(
    () => ({ tab: state.tab, setTab, push, pop, openSheet, closeSheet, openCover, closeCover, showFeedback }),
    [state.tab, setTab, push, pop, openSheet, closeSheet, openCover, closeCover, showFeedback],
  );
  return <NavContext.Provider value={api}>{render(state)}</NavContext.Provider>;
}
