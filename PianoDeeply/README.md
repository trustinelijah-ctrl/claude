# Piano, Deeply

A native SwiftUI + SwiftData iPhone app for coming back to the piano: decide what to play, work on one problem properly, keep like-for-like evidence, and enjoy playing.

## Open and run (on a Mac)

1. Open **`PianoDeeply/PianoDeeply.xcodeproj`** in Xcode 15 or later (iOS 17 SDK or later).
2. Wait for Xcode to resolve the local `PianoCore` package; it's a folder in this repo, so nothing is downloaded.
3. Pick the **PianoDeeply** scheme and an iPhone simulator, then press ⌘R.
4. To run on your own iPhone, choose your team under *Signing & Capabilities*. The bundle ID is `com.eli.pianodeeply`; change it if Xcode says it's taken.
5. Press ⌘U to run the tests: the `PianoCore` logic tests and the SwiftData persistence tests.

If you add or remove source files, regenerate the project from `project.yml` with `brew install xcodegen && xcodegen generate`, or add the files in Xcode as usual.

## What's in it

| Space | What it does |
|---|---|
| **Today** | A greeting ("Welcome back." after a week or more away, with no counts), one **Start practice** button, and a suggestion that states its reason ("Because you marked left-hand coordination as your bottleneck."). Below: the inventory card while it's unfinished, your current piece, **Just play**, and the next cold retest. |
| **Practice** | Plan a session at 20, 30, 60 or 90 minutes, or a custom length from 5 to 240. The plan is an editable template: change any step's minutes or swipe a step away. The focused problem runs through target → cold try → what got in the way → make it smaller → what fixed it → vary it → back into the music → test later. Any part can be skipped. Targets and pieces live here too. |
| **Map** | Eight branches with editable subskills, evidence examples, and six qualitative states. One bottleneck at a time, shown with the last thing you did about it. A ii–V–I explorer in F, C, B♭ and G with correct spelling, inversion controls, and smooth voice leading. |
| **Journal** | Newest-first evidence: attempts (cold and after practice badged differently), sessions, recordings, notes, and pieces started. A **Before → Now → Next** card appears only when two comparable entries exist. Filters, edit, and delete. |
| **Just play** | No goals, no error counts, no prompts. Optional timer and recording. |
| **Settings** | Optional reminders ("The piano's there whenever you'd like it." — nothing else), JSON export, microphone status, and the suggestion rules in plain words. |

### How it keeps things safe

- **Session timer.** It's two stored values: seconds banked, and when the current stretch started. Pausing, minimizing, backgrounding, or quitting the app loses nothing. A bar above the tab bar returns you to a running session.
- **Notes.** Every field writes straight into the saved record. The app also saves whenever it leaves the foreground.
- **Recordings.** Files go in `Documents/Recordings/<uuid>.m4a`, on the device only. The microphone is requested only when you tap Record, after an explanation; if you decline, the rest of the app works as usual. If a screen closes mid-take, the take is stopped and saved. A missing or unplayable file is labelled as such and can be deleted. Background audio mode keeps a take going when the screen locks.
- **Deletes.** Deleting a target removes its attempts and retests; its recordings and sessions stay. Deleting an attempt touches nothing else.

### Suggestion rules (no AI)

Checked in order, and the first match wins (`PianoCore/Sources/PianoCore/SuggestionEngine.swift`):

1. A cold retest you scheduled is due.
2. You've marked a bottleneck: the most recently worked task linked to it, or a nudge to add one.
3. The most recent task with a next step you wrote in the last 21 days.
4. A task you've practised but haven't tried cold in 14 days or more.
5. Otherwise nothing. You get the inventory or Just play instead of an invented task.

### Export

Settings → **Export as JSON** writes every record (skills, pieces, targets, sessions, attempts, retests, recording metadata, notes) with ISO 8601 dates and opens the share sheet. Audio isn't embedded, to keep the export small and simple to share. Share any recording from the Journal to get its `.m4a`; its `fileName` matches the JSON.

## Layout

```
PianoDeeply/
  project.yml                XcodeGen spec (source of truth for the .xcodeproj)
  PianoDeeply.xcodeproj      generated, committed
  PianoCore/                 pure Swift package: timer, planner, suggestions,
                             comparisons, chord theory, inventory, export format
  PianoDeeply/
    App/                     entry point, tab shell, navigation state
    Models/                  SwiftData: Skill, PracticeTask, Attempt, Retest,
                             PracticeSession, Recording, Piece, JournalNote
    Services/                audio record/playback, reminders, export
    Design/                  palette, type, buttons, drawn keyboard, feedback banner
    Features/                Today, Practice, Map, Journal, JustPlay, Onboarding,
                             Recording, Settings
    Preview/                 sample data for Xcode previews only (DEBUG)
  PianoDeeplyTests/          SwiftData persistence tests
```

## How this was verified

The build ran in a Linux container. There was no Xcode, iOS SDK, or simulator.

- **Ran and passed:** all 44 `PianoCore` tests on Linux with Swift 6.1 (`cd PianoCore && swift test`). They cover pause/resume and clock-skew timer maths, plan templates adding up exactly, suggestion order and reasons, never pairing cold with after-practice, ii–V–I spelling, voicings and voice leading in every offered key, and the export round trip.
- **Checked:** every app Swift file passes the Swift parser (`swiftc -parse`). XcodeGen generated the project, and every source file is in the right target.
- **Not done:** the SwiftUI/SwiftData app target has **not been compiled**, the persistence tests in `PianoDeeplyTests` have **not been run**, and there are no simulator screenshots. Expect to fix a few compile errors on the first ⌘B.

## Not in this build

- MIDI input and automatic note evaluation. The seam for Core MIDI would sit beside `PianoCore`, feeding attempts; nothing pretends to listen.
- Audio inside the JSON export. Recordings are shared one file at a time.
- Recovering the audio of a take cut off by force-quitting the app mid-recording. On the next launch the file shows up in the Journal as "Interrupted recording" so you can see and delete it, but it usually can't be played because it has no index. Stopping normally, leaving the screen, finishing the session, or locking the phone all keep the take.
- iCloud sync and backup beyond the device's own backups.
