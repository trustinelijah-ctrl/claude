# LOGOS

Christian and Stoic thought, learned to be spoken — in English and German.

One corpus, two surfaces:

| | Where | What it is |
|---|---|---|
| **Web** | `web/` → https://logosschool.netlify.app | The original single-file app, now an installable offline PWA with encrypted sync |
| **iOS** | `ios/` | A native SwiftUI app over the same content and the same learner data |
| **Functions** | `netlify/functions/` | `ai` (the speaking coach, Gemini via Netlify AI Gateway) and `sync` (encrypted blobs) |
| **Content** | `content/corpus.json` | Every lesson, voice, plan and passage, extracted from the web app |

```
logos/
├── web/                  deployable folder (Netlify "publish")
│   ├── index.html        the app (+ a small add-on script at the end)
│   ├── sync.js           WebCrypto half of sync
│   ├── sw.js, manifest.webmanifest, icons/
├── netlify/functions/    ai.mts, sync.mts
├── content/corpus.json   generated — the iOS app bundles this
├── scripts/              extract-corpus, check-web, golden-value generators
├── ios/                  SwiftUI app (XcodeGen spec + Swift package for the model layer)
└── netlify.toml
```

## How the pieces fit

- **Content has one source: `web/index.html`.** `npm run corpus` evaluates the
  app's script and writes `content/corpus.json`. The Netlify build also
  publishes it at `/corpus.json`; the iOS app checks that on launch and swaps
  in newer content without an App Store release. Edit a lesson on the web,
  deploy, and phones have it next time they open.
- **Learner data has one shape.** The iOS app stores the web's own document
  (`S.d`) as JSON. Backup files open on either side, and fields one side
  doesn't know about survive the round trip.
- **Sync is end-to-end encrypted.** A 20-character code is the only secret.
  Each client derives the blob id and an AES-256-GCM key from it (SHA-256
  with separate labels); the `sync` function stores ciphertext it cannot
  read. Browser (WebCrypto) and iOS (CryptoKit) are tested against each other.
- **The coach is shared.** Both clients POST `{prompt}` to
  `/.netlify/functions/ai` and get `{text}` back, using identical prompts.

## Web

```sh
cd logos
npm install
npm run check        # static checks: scripts parse, files exist, sync crypto round-trips
npm run build        # what Netlify runs: regenerates web/corpus.json
npx netlify dev      # local server with functions (needs the Netlify CLI)
```

### Deploying to Netlify

The existing project is `logosschool`. Two ways:

1. **Link the repo (recommended).** In Netlify → Project configuration →
   Build & deploy, connect `trustinelijah-ctrl/claude`, set **Base directory**
   to `logos`. `netlify.toml` supplies the build command, publish folder and
   functions. Every push then deploys; branches get preview URLs.
2. **CLI deploy from this folder:** `npx netlify deploy --build --prod` inside
   `logos/`.

Either way the `ai` function keeps working: it reads its credentials from
Netlify's AI Gateway at runtime (no keys in the repo). `LOGOS_AI_MODEL`
optionally overrides the model. The `sync` function needs nothing — Netlify
Blobs provisions itself. Both functions are rate-limited per IP.

## iOS

Requirements: Xcode 16+, iOS 17+.

```sh
cd logos/ios
brew install xcodegen
xcodegen            # creates Logos.xcodeproj from project.yml
open Logos.xcodeproj
```

Set your team under Signing & Capabilities, then run. `swift test` in
`logos/ios` runs the model-layer tests (they also run on Linux).

What's in the app:

- **Today** — greeting, the voice or figure of the day, "where you left off"
  (your last coached answer and its one fix), the next unit on the Path, recalls due.
- **Path** — 29 units in 8 stages; lessons, deep units and multi-day tracks.
- **Lesson** — open → Christian teaching → Stoic teaching → side by side →
  think it through / check yourself → say it → done. Mastery rises only on evidence.
- **Review** — spaced repetition (the web's SM-2 variant, verified against it),
  and the memorise staircase: read, fill first letters at 25/50/78%, recite.
- **Practice** — rhetoric studio (timed, coached, with the opponent's follow-up),
  morning/evening reflection, speech bank, 19 voices, 9 figures of speech.
- **Library** — sources, concept atlas, commonplace book, arguments, full-text
  search across both languages.
- **Native extras** — speak-and-see transcription on device (Speech framework),
  haptics and the web's soft tones, vector engraving plates, a daily reminder,
  backup export/import via Files, sync with the website, deep links
  (`logos://review`, `logos://voice/augustine`, …).

### Shipping to the App Store

1. Pick a bundle id you own (project.yml: `PRODUCT_BUNDLE_IDENTIFIER`).
2. Set `DEVELOPMENT_TEAM`, archive in Xcode, upload via Organizer.
3. Privacy answers: microphone and speech are used on device for transcription;
   typed answers are sent to the coach only when the learner taps "Coach";
   sync data is encrypted on device before upload.

## CI

`.github/workflows/logos.yml` checks that `content/corpus.json` matches the
web app, runs the web checks, runs the Swift tests on macOS, builds the app
for the simulator and uploads screenshots as an artifact.
