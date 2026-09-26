# LOGOS

Christian and Stoic thought, learned to be spoken, in English and German.

The same content and the same learner data run on two surfaces: the original
web app at https://logosschool.netlify.app and a native SwiftUI app for iPhone.

```
logos/
├── web/                  what Netlify publishes
│   ├── index.html        the app, plus a small add-on script at the end
│   ├── sync.js           browser side of sync (WebCrypto)
│   ├── sw.js, manifest.webmanifest, icons/
├── netlify/functions/    ai.mts (speaking coach), sync.mts (encrypted storage)
├── content/corpus.json   generated from web/index.html; the iOS app bundles it
├── scripts/              corpus extraction, checks, golden-value generators
├── ios/                  SwiftUI app: XcodeGen spec, app code, core Swift package
└── netlify.toml
```

## How the pieces fit

`web/index.html` is the only place content is written. `npm run corpus` runs the
app's script in Node and writes every lesson, voice, plan and passage to
`content/corpus.json`. The Netlify build publishes the same file at
`/corpus.json`, and the iOS app downloads it on launch, so a lesson edited and
deployed on the web reaches phones without an App Store release.

The iOS app stores the learner's progress in the web app's own JSON format.
A backup file exported on one side opens on the other, and fields one side
doesn't know about are kept.

Sync is optional. The learner holds a 20-character code. Each client derives
three values from it with SHA-256: the blob id, an auth token sent with every
request, and an AES-256-GCM key that never leaves the device. The `sync`
function stores only ciphertext and a hash of the auth token, so it can check
who is allowed to read or replace a blob but cannot decrypt it. The tests seal
data in the browser and open it in Swift, and the reverse.

Both clients use the same coach. They send `{task, input, lang}` to
`/.netlify/functions/ai`, the function fills in a fixed prompt template, and
sends back `{text}`. Clients never send a prompt, so the endpoint can't be used
as a general-purpose model.

## Web

```sh
cd logos
npm install
npm run check    # app scripts parse, referenced files exist, sync crypto round-trips,
                 # and the functions reject bad input and callers without the code
npm run build    # what Netlify runs: regenerates web/corpus.json
npx netlify dev  # local server with functions (needs the Netlify CLI)
```

The web add-ons make the site installable and usable offline, and add a sync
panel under Practice, in the "Your data" section. `netlify.toml` sets a
Content-Security-Policy that only allows same-origin requests, so learner data
can't be sent to another host.

### Deploying to Netlify

The existing project is `logosschool`. Either link the repo (Project
configuration, then Build & deploy: repository `trustinelijah-ctrl/claude`,
base directory `logos`), after which every push deploys and branches get
preview URLs, or run `npx netlify deploy --build --prod` inside `logos/`.

The `ai` function reads its Gemini credentials from Netlify's AI Gateway at
runtime; there are no keys in the repo. `LOGOS_AI_MODEL` overrides the default
model, `gemini-2.5-flash`. The coach allows 12 requests a minute per IP and sync
allows 30. Set a spending limit for AI Gateway in the Netlify team settings as
well, because per-IP limits don't stop someone using many IPs.

Deploy previews write sync data to a per-deploy store, so testing a branch
never touches production data.

## iOS

Requires Xcode 16 or later and iOS 17 or later.

```sh
cd logos/ios
brew install xcodegen
xcodegen             # creates Logos.xcodeproj from project.yml
open Logos.xcodeproj
```

Choose your team under Signing & Capabilities and run. `swift test` in
`logos/ios` runs the model-layer tests, which also run on Linux.

The app has the web app's five tabs. Today shows the voice or figure of the
day, your last coached answer with the one thing to change, the next unit on
the Path, and how many recalls are due. The Path has 29 units in 8 stages.
Review runs the web's spaced-repetition schedule and the five-step memorising
exercise. Practice has the rhetoric studio, morning and evening reflection, the
speech bank, 19 voices and 9 figures of speech. Library holds the sources, the
concept atlas, your notes, the arguments and search across both languages.

What the phone adds: spoken answers are transcribed on the device, feedback
comes as haptics and the web's soft tones, the engraving plates are drawn as
vectors, a daily reminder is available, backups go through Files, and
`logos://` links open screens directly (`logos://review`,
`logos://voice/augustine`). The sync code is kept in the Keychain.

To ship it, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to one you own,
set your team, archive in Xcode and upload from the Organizer. For the App
Store privacy form: microphone and speech recognition run on the device;
answers go to the coach only when the learner taps "Coach my answer"; sync data
is encrypted before it leaves the phone.

## CI

`.github/workflows/logos.yml` fails if `content/corpus.json` is out of date with
the web app, then runs the web and function checks, the Swift tests on macOS,
an Xcode build for the simulator, and uploads simulator screenshots.
