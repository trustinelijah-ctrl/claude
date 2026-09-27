import { Clock, DayPhrase, greeting, isLongGap, nextUpcomingRetest } from "../core/logic";
import { inventorySamples } from "../core/vocab";
import { lastColdAttempt, retestSnapshots, update, useDB, type DB } from "../store";
import { useNav } from "../nav";
import { Icon, KeyboardMotif, NavBar, useNow } from "../ui";
import { LogAttempt, PieceDetail, TaskDetail, TaskEditor, currentSuggestion, runningSession, useActions } from "./practice";
import { Inventory } from "./inventory";
import { Settings } from "./settings";

export const inventoryDone = (d: DB) =>
  inventorySamples.filter((s) => { const t = d.tasks.find((x) => x.inventorySample === s); return t && lastColdAttempt(d, t.id); }).length;

/** "What can I play today?" One clear start, one suggestion with its reason, quiet context underneath. */
export function Today() {
  const d = useDB();
  const nav = useNav();
  const actions = useActions();
  const now = useNow();
  const suggestion = currentSuggestion(d, now);
  const running = runningSession(d);
  const lastPlayed = Math.max(
    ...d.sessions.filter((s) => s.endedAt != null).map((s) => s.startedAt),
    ...d.attempts.map((a) => a.date),
    -Infinity,
  );
  const last = Number.isFinite(lastPlayed) ? lastPlayed : null;
  const returning = isLongGap(last, now);
  const done = inventoryDone(d);
  const currentPieces = d.pieces.filter((p) => p.isCurrent).sort((a, b) => b.createdAt - a.createdAt);
  const piece = currentPieces[0];
  const sTask = suggestion?.taskId ? d.tasks.find((t) => t.id === suggestion.taskId) : undefined;
  const upcoming = nextUpcomingRetest(retestSnapshots(d), now);
  const pieceLast = piece && Math.max(-Infinity, ...d.attempts.filter((a) => d.tasks.find((t) => t.id === a.taskId)?.pieceId === piece.id).map((a) => a.date));

  return (
    <div className="screen-body">
      <NavBar trailing={<button className="icon-btn" aria-label="Settings" onClick={() => nav.openSheet(<Settings />)}><Icon name="gear" size={22} /></button>} />
      <div className="pad stack" style={{ ["--gap" as string]: "30px", paddingBottom: 24 }}>
        <div className="stack" style={{ ["--gap" as string]: "10px" }}>
          <KeyboardMotif />
          <h1 className="display">{greeting(last, now)}</h1>
          <p className="title3 soft">
            {returning ? "Good to see you. Start with something you like playing."
              : new Date(now).toLocaleDateString(undefined, { weekday: "long", day: "numeric", month: "long" })}
          </p>
        </div>

        <div className="stack" style={{ ["--gap" as string]: "10px" }}>
          {running ? (
            <button className="btn-primary" onClick={() => actions.open(running)}>
              <span>Return to session · <span className="mono">{Clock.format(Clock.elapsed(running.clock, now))}</span></span>
            </button>
          ) : returning ? (
            <>
              <button className="btn-primary" onClick={actions.startJustPlay}>Just play</button>
              <button className="btn-secondary" onClick={() => actions.planSession()}>Start practice</button>
            </>
          ) : (
            <>
              <button className="btn-primary" onClick={() => actions.planSession()}>Start practice</button>
              <p className="sub soft">{[`${d.settings.lastSessionMinutes} min`, sTask && `focus: ${sTask.title}`].filter(Boolean).join(" · ")}</p>
            </>
          )}
        </div>

        {suggestion && (
          <div className="surface stack" style={{ ["--gap" as string]: "12px" }}>
            <h2 className="display-headline">{suggestion.title}</h2>
            <p className="sub soft" style={{ display: "flex", gap: 8 }}>
              <span style={{ color: "var(--brass)", marginTop: 1 }}><Icon name={suggestion.rule === "retestDue" ? "snowflake" : "sparkles"} /></span>
              {suggestion.reason}
            </p>
            <div className="row2">
              {suggestion.rule === "retestDue" && sTask ? (
                <button className="btn-secondary" onClick={() => nav.openSheet(<LogAttempt taskId={sTask.id} phase="cold" retestId={suggestion.retestId} />)}>Do the retest</button>
              ) : suggestion.rule === "bottleneckNeedsTask" ? (
                <button className="btn-secondary" onClick={() => nav.openSheet(<TaskEditor skillId={d.skills.find((s) => s.isBottleneck)?.id ?? null} />)}>Add a target for it</button>
              ) : (
                <button className="btn-secondary" onClick={() => actions.planSession(suggestion.taskId ?? undefined)}>Practise this</button>
              )}
              {sTask && <button className="btn-plain" onClick={() => nav.push(<TaskDetail id={sTask.id} />)}>Open</button>}
            </div>
          </div>
        )}

        {done < inventorySamples.length && !d.settings.inventoryHidden && (
          <div className="surface stack" style={{ ["--gap" as string]: "10px" }}>
            <h2 className="display-headline">Six-sample inventory</h2>
            <p className="soft">{done === 0
              ? "Six short things played cold, about fifteen minutes. A starting point to compare against in four weeks."
              : `${done} of 6 logged. The rest can wait until you feel like it.`}</p>
            <div className="row2">
              <button className="btn-secondary" onClick={() => nav.openSheet(<Inventory />)}>{done === 0 ? "Start" : "Continue"}</button>
              <button className="btn-plain" onClick={() => update((db) => { db.settings.inventoryHidden = true; })}>Hide</button>
            </div>
          </div>
        )}

        {piece && (
          <button className="surface row-card" onClick={() => nav.push(<PieceDetail id={piece.id} />)}>
            <span className="row-icon"><Icon name="note" /></span>
            <span className="grow">
              <span className="headline block">{piece.title}</span>
              <span className="sub soft block">
                {[piece.composer || null, pieceLast && Number.isFinite(pieceLast) ? `last worked on ${DayPhrase.since(pieceLast, now)}` : null,
                  currentPieces.length > 1 ? `+${currentPieces.length - 1} more current` : null].filter(Boolean).join(" · ") || "No targets yet"}
              </span>
            </span>
            <Icon name="chev" />
          </button>
        )}

        {!returning && !running && (
          <button className="row-card plain" onClick={actions.startJustPlay}>
            <span className="row-icon"><Icon name="note" /></span>
            <span className="grow">
              <span className="headline block">Just play</span>
              <span className="sub soft block">No goals. A timer and recording only if you want them.</span>
            </span>
          </button>
        )}

        {upcoming && (
          <button className="link-quiet" onClick={() => nav.push(<TaskDetail id={upcoming.taskId} />)}>
            <Icon name="snowflake" />Next cold retest: {upcoming.taskTitle}, {DayPhrase.until(upcoming.dueDate, now)}
          </button>
        )}
      </div>
    </div>
  );
}
