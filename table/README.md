# TABLE — Chess, together.

A native iPad app that turns the whole iPad into a chessboard for two people sitting
opposite each other. No accounts, no network, no onboarding: open it and play.

Swift + SwiftUI, iPadOS 17 or later, iPad only, works fully offline.

## Build and run

1. Open `table/Table.xcodeproj` in Xcode 16 or later.
2. Select the **Table** scheme and an iPad simulator or a connected iPad.
3. To run on a device, choose your team under *Signing & Capabilities* (the project
   ships with automatic signing and no team).
4. Run (⌘R).

The project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen).
The generated `Table.xcodeproj` is committed, so you do not need XcodeGen to build. After
adding or removing files, run `xcodegen generate` in `table/`.

### Tests

| What | How |
| --- | --- |
| Chess rules (35 tests, perft to depth 3–4 on six reference positions) | `cd table/ChessCore && swift test`, or open `ChessCore/Package.swift` in Xcode and press ⌘U |
| Interaction UI tests (tap, drag, illegal drops, capture, undo, castling, promotion, checkmate, settings, rotation, rapid moves) | ⌘U on the **Table** scheme, on an iPad simulator |
| Screenshots across iPad sizes | `ScreenshotTests` in the UI test target; CI runs it on iPad mini, iPad Air 11" and iPad Pro 13" |

The GitHub Actions workflow `.github/workflows/table.yml` runs all of the above on a macOS
runner on every push that touches `table/`, and publishes the screenshots to the
`table-ci-shots` branch.

## How it is put together

```
table/
  ChessCore/            Swift package: the rules engine, no UI dependencies
    Sources/ChessCore/  Models, Position (move generation, FEN, SAN), ChessGame (record, draws)
    Tests/              Perft and rule edge cases
  App/
    TableApp.swift      Entry point
    Session/            GameSession (game state, piece identity, move timing), PieceToken
    Board/              BoardView (gesture), BoardSurface, BoardMarks, TokenView, geometry
    Pieces/             PieceArt (vector renderer), PieceArtwork (generated paths)
    Feedback/           AudioManager, HapticManager, FeedbackCoordinator
    Chrome/             RootView, TableLayout, PlayerPanel, ResultOverlay
    Settings/           SettingsStore (UserDefaults), SettingsCard
    Design/             Themes and motion constants
    Resources/          Asset catalog (board materials, icon) and Sounds/
  UITests/              Interaction tests and screenshot capture
  tools/                Scripts that generate the pieces, materials, icon and sounds
```

**Rules engine.** `ChessCore` is a self-contained engine written for this project
(no third-party dependency). It implements complete legal move generation (pins,
checks, castling through/out of/into check, en passant including the discovered-check
case, promotion to any piece), checkmate and stalemate, insufficient material,
threefold repetition and the fifty-move rule as claims, and fivefold repetition and the
seventy-five-move rule as automatic draws. Repetition compares placement, side to move,
castling rights and only a *capturable* en-passant square, as the FIDE rules require.
Correctness is checked with perft node counts against the published reference values.

**One board, never flipped.** White's first rank is always nearest the bottom edge. A
single `BoardGeometry` maps squares to points; every gesture is converted back through it.
By default Black's pieces are turned 180° to face the Black player (switchable in
settings). Each player's panel is laid out once; Black's is the same full-window layer
rotated 180° about the centre, so it lands on Black's side, facing Black, in every
orientation and window size.

**Layout.** `TableLayout` picks the largest square board that leaves each player a usable
panel, trying both panels-above-and-below and panels-beside, and keeps whichever board is
larger. Margins are symmetric so the two halves mirror exactly. Works in portrait,
landscape, Split View and Stage Manager windows; rotation and resizing re-layout without
touching game state.

**Pieces.** An original set drawn as vector paths: symmetric pieces are authored as a
lathe profile (one side of a turned piece) and mirrored, the knight is drawn freehand,
and all share one base and one stroke weight. `tools/pieces.py` is the single source;
it renders preview sheets and generates `PieceArtwork.swift`. Pieces are rendered with
SwiftUI `Canvas`: cylindrical shading lit from the upper left, a fine rim light so dark
pieces read on dark squares, and turned grooves.

**Materials.** `tools/materials.py` builds each board surface the way a veneered board is
assembled: 64 separately cut squares with their own grain offset, direction and tone,
plus hairline seams. Walnut Nocturne uses black walnut and maple with a gilt inlay;
Ivory & Slate uses honed ivory stone and slate.

**Touch.** One `DragGesture(minimumDistance: 0)` on the board handles both styles:
tap a piece then a square, or press and drag. Pressing a piece selects and lifts it at
once (legal destinations appear immediately). After 5 pt of travel it becomes a drag:
the piece follows the finger at exactly the grip point (no snap), floats a third of a
square away from the finger toward the far side of the board so the finger does not hide
it, grows slightly and casts a softer, wider shadow. The square under the piece (not under
the finger) is outlined as the drop target. A legal drop settles with a short spring; an
illegal one floats back home. Each piece keeps its identity across moves, so captures,
castling, undo and new game all animate physically: the rook follows the king a beat
later, a taken piece fades and shrinks as the attacker lands, and on a new game every
piece glides home in a wave from White's side.

**Sound.** `tools/sounds.py` synthesizes the palette offline with modal synthesis: a
short excitation ringing a bank of damped resonances for a felted boxwood piece on a
walnut board, and struck wooden bars with marimba-tuned partials for the tonal accents.
Energy is concentrated in the band iPad speakers reproduce well, so it holds up at low
volume. 17 files, several variations per frequent event. At runtime `AudioManager` decodes
everything into memory once and plays through a fixed pool of 12 `AVAudioPlayerNode`s on one
`AVAudioEngine`, with five pitch variations per sample, a peak limiter, and stereo pan
by board file. Sounds are scheduled on the audio clock, so the placement knock lands
on the frame the piece lands (a tap move travels ~150–270 ms; the sound is timed to its
landing, not its start). The session is `.ambient`, which respects the silent setting
and mixes with music playing at the table. Interruptions, route changes and media
server resets are handled.

To use recorded sounds, drop files with the same names (`place_1.wav`, `place_2.wav`,
`capture_1.wav`, …; `.wav`, `.caf`, `.aif` or `.m4a`) into `App/Resources/Sounds`.
Any number of numbered variations per event is picked up.

**Haptics.** `HapticManager` checks `CHHapticEngine.capabilitiesForHardware()` at
runtime. iPads without a haptic actuator get no haptic calls at all; the tactile feel
comes from the lift, shadow, sound and settle instead.

**Persistence.** The game (initial position, move list, any result) is saved after every
change to Application Support and restored on launch. Settings live in UserDefaults.

## Launch arguments (testing and screenshots)

| Argument | Effect |
| --- | --- |
| `-fresh YES` | Start from the opening position instead of the saved game |
| `-moves "e2e4 e7e5 …"` | Start from the position after these moves |
| `-select e2` | Select a square on launch |
| `-openSettings white\|black` | Open settings facing that player |
| `-showResult YES` | Show the result card if the game is over |
| `-simulateWindow half\|third\|square` | Confine the app to a Split View / Stage Manager sized region |
| `-theme slate`, `-soundEnabled NO`, `-showCoordinates NO`, `-pieceFacing white` | Override settings |

## Status

See the bottom of this file for the hardware checklist.

### Finished

- Complete legal chess with automated tests, including every special rule and draw rule.
- Tap-to-move and drag-to-move with lift, finger offset, drop target, settle and return.
- Animated captures, castling, promotion (picker on the board, facing the promoting
  player), check glow, checkmate and draw result card readable from both seats.
- Undo (takes back moves and withdraws resignations or claimed draws), new game,
  draw claims (threefold, fifty-move), resignation, draw by agreement.
- Two themes, coordinates and move hints toggles, piece-facing option, sound on/off and
  volume, all persisted.
- Original vector pieces, procedural board materials, synthesized sound palette, app icon.
- Responsive layout for every iPad size, both orientations, Split View and Stage Manager.

### Not yet / known limitations

- Sounds are synthesized, not recorded. They are designed to be replaced by recordings
  without code changes.
- Feel can only be judged on real hardware: touch latency, speaker balance and the
  exact timing of sound against motion were tuned by reasoning and on the simulator.
- No move list display or PGN export (the full history is kept internally, with SAN).
- Apple Pencil Pro haptics (`UICanvasFeedbackGenerator`) are not used yet.
- No VoiceOver path for making moves (the board reports state; moves need touch).

## Hardware checklist (on a real iPad)

1. **Latency.** Drag a piece in fast circles: it should stay locked to the same point
   under your finger with no visible lag or catch-up, at 120 Hz on ProMotion iPads.
2. **No snap at pickup.** Press slightly off-centre on a piece and drag: the piece must
   not jump to centre itself under the finger; it should lift smoothly away from it.
3. **Sound sync.** Tap-move a rook across the whole board: the knock should coincide with
   the landing, not the start. Drag-drop: the knock should be near-instant on release.
4. **Speakers.** At 20–30% volume in a quiet room, placement should be clearly audible
   and warm, capture noticeably heavier, pickup barely there. Rotate the iPad: pan should
   follow the board (a move on the a-file sounds left of one on the h-file from White's seat).
5. **Rapid play.** Make ten quick tap moves in a row: no clipped, distorted or stacked
   sounds, no stray pieces.
6. **Opposite seat.** From Black's side, drag Black's pieces: the lifted piece floats
   away from your finger toward White's side; your panel, settings and the promotion
   picker face you.
7. **Interruptions.** Start music in another app, then play: TABLE mixes with it. Take a
   call or trigger Siri mid-game; afterwards sounds still play.
8. **Resume.** Force-quit mid-game and reopen: the game is exactly where it was.
9. **Silent mode / volume.** With the volume at zero or sound off in settings, nothing plays.
10. **Haptics.** On an iPad without a Taptic Engine, nothing vibrates. (No current iPad
    has one; this path is there for completeness.)
