# 64: release readiness review

*Reviewed 25 October 2026, branch `claude/table-chess-ipad` at `1dfe490`. Everything here was checked in the code, not taken from comments or earlier documents. The 44 ChessCore tests pass (`swift test`, run on Linux). Screenshots on `ci-shots` match this commit.*

---

## 1. Verdict

**Ready after fixes.** The app itself is in good shape. The game is complete and well tested, StoreKit 2 is handled properly, all debug-only paths are compiled out of Release, and nothing crashes on a fresh install as far as the code shows. Four things would get it rejected, either at upload or in review: there is no privacy manifest, the free-trial wording states the wrong price after the trial, the privacy policy is incomplete and hosted on a temporary URL, and the analytics setup contradicts what you will declare to Apple. A fifth item covers building with Xcode 26, which CI has never done. All five together take about a day of work. Submitting by **about 20 November** leaves room for one rejection before 1 December.

---

## 2. Blockers (fix before submitting)

### B1. No privacy manifest: App Store Connect will reject the upload

**Evidence.** There is no `PrivacyInfo.xcprivacy` anywhere in `sixtyfour/` (`find` returns nothing). The app calls two "required reason" APIs:

- `UserDefaults`: `SettingsStore.swift:27-101`, `ProStore.swift:38,61,104-112`, `RecordBook.swift:230`, `PuzzleView.swift`, `ReviewPrompt.swift:11-17`, `RootView.swift:274-277`.
- `mach_absolute_time()`: `AudioManager.swift:160`. This falls in the "system boot time" category.

**Why it matters.** Since May 2024, App Store Connect refuses builds that use these APIs without declaring a reason. The error is ITMS-91053, "Missing API declaration". The TelemetryDeck package ships its own manifest (checked: `Sources/TelemetryDeck/PrivacyInfo.xcprivacy`), but that manifest covers only the SDK's own calls, not the app's.
[Apple: Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) · [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

**Fix.** Add `App/PrivacyInfo.xcprivacy`. It sits under `App/`, so XcodeGen picks it up as a resource. Then run `xcodegen generate`. Contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>   <!-- TelemetryDeck declares its own -->
  <key>NSPrivacyAccessedAPITypes</key><array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>CA92.1</string></array>
    </dict>
    <dict>
      <key>NSPrivacyAccessedAPIType</key><string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key><array><string>35F9.1</string></array>
    </dict>
  </array>
</dict></plist>
```

After archiving, open Organizer, right-click the archive and choose **Generate Privacy Report**. Check that it lists exactly what you declare in App Privacy (see B4).

### B2. The free-trial offer states the wrong price after the trial

**Evidence.** `ProCard.swift:97-98`: the Yearly row's note says **"7 days free, then €1.67 a month"**. After the trial the customer is charged €19.99 for a year, not €1.67 a month. `ProCard.swift:149` labels the main button "Start free week". The only small print near it, at `ProCard.swift:124`, says "Renews automatically. Cancel anytime." and gives no price or period. You can see this on `phonese-12-paywall-portrait.png`.

**Why it matters.** Apple's subscription rules: *"In the purchase flow for a free trial, clearly indicate how long the free trial lasts and the price billed once the free trial is over."* And: *"the amount that will be billed must be the most prominent pricing element"*, with any monthly breakdown "subordinate". The €19.99 does appear on the right of the row, but the sentence about what happens after the trial gives a different amount. Reviewers reject this pattern regularly under 3.1.2.
[Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/) · [Guideline 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions)

**Fix.** This is a copy change only:
- Yearly note (trial available): `7 days free, then €19.99 a year` using `pro.price(.yearly)`. The per-month figure can follow in smaller text: `(€1.67/month)`.
- Under the button, when Yearly is selected and the trial is available: `Free for 7 days, then €19.99 a year. Renews automatically until cancelled; cancel at least 24 hours before the trial ends in Settings ▸ Apple ID ▸ Subscriptions.` For Monthly: `€3.99 a month, renews automatically until cancelled.`
- Keep Restore, Terms of Use and Privacy Policy where they are. They are fine.

### B3. Privacy policy: hosted on a branch URL and missing required content

**Evidence.**
- `ProCard.swift:30` hard-codes `https://github.com/trustinelijah-ctrl/claude/blob/claude/table-chess-ipad/sixtyfour/PRIVACY.md`. It works today (HTTP 200, public repo). But it points at a **feature branch**. It will return 404 the day that branch is merged, renamed or deleted, and the URL is compiled into the binary, so fixing it then needs an app update. It also sends every reviewer and customer into the whole public repo, which includes your revenue model, growth plans and the "AI runs my app" PDF.
- `PRIVACY.md:1-38` has no data controller (your name and postal address), no contact email, no retention or deletion period, no instructions for requesting deletion, and no list of what the SDK sends automatically. TelemetryDeck adds OS version, device model, app version, locale and a hashed device ID to every signal, and sends a "session started" signal by default. Line 38 points to "the support link on 64's App Store page", which does not exist yet.

**Why it matters.** Guideline 5.1.1(i) requires the policy to *"identify what data… the app collects… and all uses"*, confirm third-party protection, and *"explain its data retention/deletion policies and describe how a user can revoke consent and/or request deletion."* Separately, a German or Dutch developer must meet GDPR Art. 13 (controller identity, legal basis, rights, recipients). That is legal exposure rather than App Review, but it is real.
[Guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

**Fix.**
1. Make a small permanent site, for example GitHub Pages on a **separate** repo such as `sixtyfour-app.github.io` or your own domain, with `/privacy`, `/support` (a contact email) and, for Germany, `/impressum`.
2. Rewrite the policy to cover: who you are and how to reach you; what is collected (if analytics stays on: the event names listed below, plus OS version, device model, app version, locale and a hashed per-install identifier); why (legitimate interest in improving the app, Art. 6(1)(f)); the processor (TelemetryDeck GmbH, EU hosting); retention (TelemetryDeck's period); how to object or request deletion (email); and that Apple handles payments.
3. Change `ProCard.privacyURL` to the new URL before archiving. `SettingsCard.swift:338` uses the same constant.

The events the app actually sends are `game.started`, `game.finished`, `puzzle.solved`, `paywall.shown`, `purchase.started`, `purchase.completed`, `purchase.restored`, `onboarding.completed` and `ambience.selected`. Parameters are the opponent level, the outcome, the plan, the source screen and the ambience scene. No free text.

### B4. Analytics are switched off in code, but the SDK is still linked and the policy says they are on

**Evidence.** `Analytics.swift:9`: `static let appID = ""`. With an empty ID, `start()` returns early and nothing is ever sent. But TelemetryDeck is still linked (`project.yml:20-23,33-34`), and its privacy manifest declares **Product Interaction** and **Device ID** (not linked, used for analytics). Meanwhile the policy (`PRIVACY.md:22-29`) says analytics are on, and the launch plan says "64 collects no data".

**Why it matters.** Your App Privacy answers in App Store Connect have to match what the app does (5.1.2 and the App Privacy requirements). Xcode's privacy report will show the SDK's declared data types regardless of the empty ID. Answering "Data Not Collected" while the bundled manifest says otherwise is an inconsistency you can avoid.

**Fix.** Pick one and make code, manifest, policy and label agree:
- **A. Analytics on (recommended: you need to know paywall conversion).** Put the real TelemetryDeck App ID in `Analytics.swift:9`. In App Privacy, declare **Identifiers ▸ Device ID** and **Usage Data ▸ Product Interaction**, both for *Analytics* only, *not linked* to identity, *not used for tracking*. This is TelemetryDeck's own guidance: [TelemetryDeck: Apple's app privacy details](https://telemetrydeck.com/docs/articles/apple-app-privacy/).
- **B. Analytics off at launch.** Remove the TelemetryDeck package and `Analytics.swift`, or replace the latter with a stub. Delete the analytics section of the policy and answer **Data Not Collected**.

### B5. No Release build has ever been compiled, and uploads must come from Xcode 26

**Evidence.** CI builds only `-configuration Debug` (`.github/workflows/sixtyfour.yml:49`) on `macos-15` with no Xcode version selected (`:22`). Release-only code paths, the `#else` branches of `#if DEBUG`, are never compiled. `project.yml:13` has `DEVELOPMENT_TEAM: ""`, and `project.yml:11` has `MARKETING_VERSION: "0.2"`.

**Why it matters.** Since 28 April 2026, App Store Connect accepts only apps built with Xcode 26 and the iOS 26 SDK ([Apple: Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)). Building with the 26 SDK also switches standard controls to Liquid Glass. That affects the segmented pickers, menus, toggles and sliders in Options and on the home screen. The custom board and cards are unaffected, but the controls need a visual check.

**Fix.**
1. Set your team ID in `project.yml`. Set `MARKETING_VERSION: "1.0"` (the App Store version must match) and run `xcodegen generate`.
2. On your Mac, with Xcode 26: Product ▸ Archive (Release), then Distribute ▸ App Store Connect ▸ upload to TestFlight. Fix any warnings it raises.
3. Add a CI step: `sudo xcode-select -s /Applications/Xcode_26*.app` plus `xcodebuild … -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`.
4. Install the TestFlight build and run the test plan in section 6. Confirm that Options ▸ More has **no** Developer section and that a long press on the logo does nothing. The CI screenshots show the Developer section because they are Debug builds.

If the Liquid Glass controls look wrong next to the custom gold styling, `UIDesignRequiresCompatibility = YES` in Info.plist is a stopgap that Apple says is temporary.

---

## 3. Should fix before launch (strongly recommended, not blocking)

### S1. Hard-coded euro prices and an optimistic "free week" when the store doesn't answer

`ProStore.swift:22-29,79` falls back to fixed `€19.99 / €3.99 / €39.99 / €24.99` and `€1.67` when products haven't loaded. `ProStore.swift:34` shows the Founder row whenever the products list is empty. `ProStore.swift:43` defaults `trialAvailable = true`, so the home button (`HomeView.swift:109`) and the paywall promise a free week even to people who have already used it, until the store replies. A US reviewer whose products fail to load would see euro prices and then get "The App Store isn't reachable" (`ProStore.swift:133`). That is the classic "we couldn't complete the purchase" rejection under 2.1.

These fallback prices also differ from the launch plan's recommended prices (€14.99, €2.99, €29.99).

**Fix:** while `products` is empty, show a spinner and a "Try again" button instead of prices. Retry `load()` when the paywall opens. Default `trialAvailable` to `false` until eligibility is known. The real protection is in App Store Connect: submit all four products with version 1.0 (checklist step 9).

### S2. Sound plays through the silent switch by default

`SettingsStore.swift:73` (`Keys.silentMode: true`) and `AudioManager.swift:76,190` use the `.playback` category, which ignores the Ring/Silent switch. Someone who installs 64 in a meeting or on a train with the phone on silent will hear piece clicks. That is a poor first impression and the opposite of what iOS users expect from game sound effects ([AVAudioSession categories](https://developer.apple.com/documentation/avfaudio/avaudiosession/category)). The README (line 147) still says the session is `.ambient`.

**Fix:** default `playInSilentMode` to `false` (`.ambient`) and keep the toggle. The onboarding line "Sound on." already nudges people to turn sound up.

### S3. Screenshot hook `-pro` still honored in Release

`ProStore.swift:61` and `:112` read `UserDefaults "pro"`, which is set by the `-pro YES` launch argument, in every build. An App Store customer can't pass launch arguments, so the practical risk is near zero. But it contradicts the comment at `ProStore.swift:95-96` and is the kind of thing a later change could expose. **Fix:** wrap both reads in `#if DEBUG`. Do the same for `-showProWelcome`, `-seedLibrary` and the other hooks in `RootView.swift:377-393` and `SixtyFourApp.swift:28-39`, or leave those, since they only change what is shown.

### S4. Entitlement refresh, managing a subscription, restore wording

- `refresh()` runs only at launch and on `Transaction.updates` (`ProStore.swift:62-70`). A subscription that lapses while the app stays in memory for days stays "Pro" until the next cold start. **Fix:** call `Task { await pro.refresh() }` in `RootView.scenePhaseChanged(.active)` (`RootView.swift:288`).
- There is no "Manage subscription" control. Options ▸ More only shows "Active" (`SettingsCard.swift:310-318`). **Fix:** add a button with `.manageSubscriptionsSheet(isPresented:)` for subscribers. This cuts support email and refund requests.
- `ProStore.swift:173`: "No active 64 Pro **subscription** was found". Lifetime and Founder buyers can restore too, so say "No 64 Pro purchase was found for this Apple ID."

### S5. Sign in with Apple leftovers

`AccountStore.swift:3` still imports `AuthenticationServices`. Lines 257-283 still hold `signedIn`, `checkAppleCredential` and `ASAuthorizationAppleIDProvider`, and `RootView.swift:53` calls `checkAppleCredential()` on every launch. No UI reaches a sign-in, there is no entitlement in `project.yml`, and `kind == .apple` can't happen on a fresh install, so this is harmless today. But it is dead code that touches an Apple ID API, and the README (lines 24-28 and 191) still describes Sign in with Apple. **Fix:** delete those methods and the `.task`, and update the README. Leaving sign-in out is the right call: keeping it would bring in the account-deletion requirement (5.1.1(v)) and a demo-account requirement for review.

### S6. German and Dutch launch with an English-only app

Every string is English, and many are passed as `String` rather than literals (for example `OnboardingView.swift:37-47`, `ProCard.swift:18-27`), so a String Catalog would not even extract them automatically. The growth review plans German and Dutch store names ("64: Schach am Tisch"). That is allowed, but a German product page in front of an English app gets 1-star "nur Englisch" reviews. Apple shows "Languages: English" on the page.

**Fix, pick one:** (a) localize to German at least. That means about 150 short strings: add `Localizable.xcstrings` and change `String` properties to `LocalizedStringResource`. Or (b) keep the store page in English for 1.0, or say "App-Sprache: Englisch" in the German description. Option (a) is worth it for your two home markets.

### S7. Small iPhone paywall clips mid-line; no Dynamic Type

On iPhone SE (`phonese-12-paywall-portrait.png`) the feature list is cut through the middle of "All checkmate puzzles…", with no scroll indicator (`ProCard.swift:34-37`). It looks broken rather than scrollable. **Fix:** `showsIndicators: true` or a fade mask at the bottom edge, or shorten the list on compact heights.

Every font is `.system(size:)` with a fixed size (all views), so Larger Text has no effect. That is not a rejection reason. Just don't claim "Larger Text" or "VoiceOver" support if you fill in Apple's optional Accessibility Nutrition Labels. VoiceOver can't make moves (README "Not yet").

### S8. Audio rebuild after a media-services reset

`AudioManager.swift:198-206` creates a new `AVAudioEngine` but re-attaches the same `submix` node (a `let`, created for the old engine) and does not call `configureSession()`. Media-services resets are rare (a system audio-daemon crash), but attaching a node that belongs to another engine can raise an Objective-C exception. **Fix:** make `submix` a `var` and recreate it in `rebuild()`, and call `configureSession()` first.

### S9. Founder offer must really end

The paywall says "Launch price, for the first weeks only" (`ProCard.swift:102`). The app switches to Lifetime only when the Founder product stops loading, which happens when you **remove it from sale** in App Store Connect (`ProStore.swift:34`). Put an end date in your calendar now. A "first weeks only" claim that never ends is misleading under 2.3 and EU consumer law. Make sure the Lifetime product is approved and live before you pull Founder. If neither loads, the row shows a fallback price and fails.

---

## 4. Nice to have after launch

- **Clock survives a force-quit.** `GameSession.configure(timeControl:)` (`GameSession.swift:137-143`) gives both players full time again after a relaunch, because the clock isn't saved. Persist it with the game.
- **Small leak:** `pendingWork` only drops cancelled tasks (`GameSession.swift:679`), so finished ones pile up over a long session. Filter on completion too.
- **Upgrade path:** subscribers can't buy Lifetime in the app, because the purchase section hides once `isPro` is true. Some yearly subscribers will want to "buy out".
- **Win-back and offer codes** for creators (the launch plan's "free year of Pro"). Use subscription offer codes rather than promo codes.
- **VoiceOver moves** (announce squares, double-tap to pick and place) and Dynamic Type.
- **iCloud sync** of games and records (`GameLibrary` and `RecordBook` are local only).
- An in-app "Contact support" mail link in Options ▸ Help.

---

## 5. App Store Connect: owner checklist, in order

Allow 1–2 weeks for steps 1–4. They depend on Apple's checks, not on you.

1. **Enroll** in the Apple Developer Program as an individual (€99/year). Use your legal name: it appears as the seller.
2. **Agreements, Tax and Banking** (Business section): accept the **Paid Apps Agreement**, fill in the tax form (a W-8BEN as a non-US individual; Apple handles EU VAT on sales), and add your bank account (IBAN). Until this shows "Active", in-app products do not load, even in review.
3. **EU trader status (Digital Services Act)**: declare yourself a *trader*, because you sell in-app purchases. Apple verifies and **publicly shows** your address, phone and email on EU product pages. Use a business address or a virtual office if you don't want your home address shown. Without this the app isn't available in EU storefronts. [Apple: DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
4. **App Store Small Business Program**: apply right after enrollment. The commission drops to 15%. [Apple: Small Business Program](https://developer.apple.com/app-store/small-business-program/)
5. **Certificates, Identifiers & Profiles**: register the bundle ID `app.sixtyfour.chess`. No extra capabilities are needed. In-App Purchase is on by default; don't add Sign in with Apple.
6. **New app**: platform iOS, name **"64: Chess Across the Table"** ("64" alone will almost certainly be taken), primary language English, bundle ID as above, SKU `sixtyfour-1`.
7. **App Information**: category **Games ▸ Board** (secondary Games ▸ Puzzle). Content rights: you do use third-party content (CC0 Kenney sounds, public-domain ambience) that you have the rights to, so answer accordingly. Age rating questionnaire (the new 2025 version): answer "None" everywhere, "No" to web access, user content, chat and gambling, and "Yes" to in-app purchases. That gives **4+**. **Do not** choose the Kids category: the third-party analytics and external links on the paywall conflict with guideline 1.3.
8. **Pricing and Availability**: Free. Choose territories (all, or start with the EU, UK, US, CA and AU).
9. **In-App Purchases and Subscriptions.** Product IDs must match `ProStore.swift:17-20` exactly.
   - Subscription group **"64 Pro"**, with a group display name localized in EN, DE and NL.
     - `app.sixtyfour.pro.yearly`: 1 year. Introductory offer: **Free, 1 week**, all territories.
     - `app.sixtyfour.pro.monthly`: 1 month.
     - Put yearly and monthly on the same level, or yearly above monthly. Either works, because both unlock the same thing.
   - Non-consumables `app.sixtyfour.pro.lifetime` and `app.sixtyfour.pro.founder`.
   - For each product: display name and description (EN/DE/NL), price, **Family Sharing ON** (the paywall says "Shared with your family"; this is irreversible once turned on), and a **review screenshot** of the paywall.
   - Decide final prices now. Code fallbacks, the StoreKit file and the launch plan disagree. Whatever you choose, the app shows App Store prices once loaded.
10. **App Privacy**: privacy policy URL (the new permanent one from B3). Answers, per your B4 choice:
    - *Option A (analytics on):* "Yes, we collect data". **Identifiers ▸ Device ID** and **Usage Data ▸ Product Interaction**, each with purpose *Analytics*, *not linked* to the user, *not used for tracking*. Nothing else: purchases go through Apple and are not yours to declare.
    - *Option B (SDK removed):* "No, we do not collect data".
11. **Version 1.0 page**:
    - **Screenshots**: iPhone **6.9"**, 1320 × 2868 portrait (1290 × 2796 also accepted), and iPad **13"**, 2064 × 2752 portrait or 2752 × 2064 landscape. Up to 10 each, PNG or JPEG, no transparency. Apple scales these down for smaller devices. [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
      - The CI's iPhone SE shots (750 × 1334) are **not** an accepted size. Run the `[iphone]` CI mode, which already targets the Pro Max simulator.
      - The CI shots come from Debug builds. Don't use the Options ▸ More one, because it shows the Developer section.
      - The iPad "landscape" shots are saved unrotated (2064 × 2752 with sideways content). Rotate them before uploading.
    - App preview video: optional. Your muted 15–30 s clip will help conversion.
    - **Description**: end with "Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ · Privacy: <your URL>". Apple requires the Terms link in the metadata as well as in the app.
    - Keywords, subtitle and promotional text: from the growth review. Don't describe the app as German-language unless you do S6(a).
    - **Support URL** (required, with a working contact) and Marketing URL (optional).
    - Copyright: `2026 <your name>`.
    - **In-App Purchases** section: select all four products so they go into review with the binary.
    - **Build**: the TestFlight build from B5. Export compliance is answered by `ITSAppUsesNonExemptEncryption = NO` (correct, since the app uses only HTTPS).
    - **App Review information**: no sign-in needed. Notes, for example: *"64 is a chess app; no account. 64 Pro is offered as a yearly subscription with a 1-week free trial, a monthly subscription, and a one-time Founder lifetime (a launch-price version of Lifetime; only one lifetime product is shown at a time). The paywall opens from Home ▸ 'Try 64 Pro free for a week', or any locked board, puzzle or opponent. Restore is on the paywall and in Options ▸ More."*
    - **Version release**: *Manually release this version*, so approval before 1 December doesn't publish early.
12. **Sandbox**: Users and Access ▸ Sandbox ▸ add 2 testers, with new email addresses not used for any Apple ID, one with storefront Germany. Use them for section 6.
13. **TestFlight**: add yourself as an internal tester and install the build.
14. **Submit** around 18–20 November. If rejected, reply in Resolution Center with the fix and resubmit the same day.

---

## 6. Test plan on a real device (under an hour, TestFlight Release build)

Sandbox subscriptions renew fast (1 week ≈ 3 min, 1 month ≈ 5 min, 1 year ≈ 1 hour by default, and you can change this in the sandbox account settings), so expiry can be tested in one sitting. On the device, sign in to the sandbox account under **Settings ▸ Developer ▸ Sandbox Apple Account**, or wait for the prompt on the first purchase.

**A. Fresh install (5 min)**
1. Delete 64, reinstall from TestFlight, turn on airplane mode, launch. The welcome should show, then the paywall about 1 s after "Start playing". The paywall should show a loading or retry state, not euro prices (after S1). Close it with "Not now".
2. Play 5 moves against Casual offline. Force-quit and reopen: the game resumes on Home with "Continue game".
3. Options ▸ More: **no Developer section**. Long-press the logo on Home: nothing happens.

**B. Purchases (25 min)**, airplane mode off
4. Paywall ▸ Yearly ▸ "Start free week". The Apple sheet must show "1 week free, then €X/year". Confirm. The Pro welcome shows the trial end date, and the Marble board, ambience, Master level and all puzzles unlock.
5. Settings ▸ Developer ▸ sandbox account ▸ Manage ▸ cancel the subscription. Wait about 5 minutes, then cold-start the app. Pro should be gone, and the board and level should be back to the free defaults.
6. Buy **Monthly**. Pro is on, and the welcome shows no trial text.
7. Delete the app, reinstall, open the paywall ▸ **Restore**. You should get "64 Pro is back". Also launch without pressing Restore: Pro should already be on, because current entitlements are read at launch.
8. With the second sandbox tester (fresh, German storefront): buy **Founder lifetime**. Check that prices show in € with German formatting and that the welcome says "Yours for good".
9. Paywall ▸ select Yearly ▸ start the purchase ▸ **Cancel** on the Apple sheet. No message, no charge, and the button is usable again.
10. Tap Terms of Use and Privacy Policy: both open, and the privacy page is the new permanent URL.

**C. Sound and interruptions (15 min)**
11. Silent switch on (or Action Button set to Silent), sound on in Options. Pieces should be silent with the default after S2, and audible when "Play in silent mode" is on.
12. Play music in Apple Music, then play 64. Both should be heard (they mix).
13. Mid-game: take a FaceTime call from another device, trigger Siri, set a 1-minute timer. Afterwards, piece sounds still play and ambience (with Pro) resumes.
14. Connect and disconnect AirPods mid-game. Sound follows the route with no silence afterwards.
15. Set a 1-minute clock, start, send the app to the background for 30 s, and return. The clock should have paused, not run.

**D. iPad (10 min, if you have one)**
16. Rotate through all four orientations mid-drag and mid-animation. Open Split View at ⅓ and ½ and a Stage Manager window. Nothing should overlap, and the paywall and Options should stay reachable.
17. VoiceOver on: Home buttons, the paywall plans and the purchase button read sensibly ("Yearly, selected", and so on).

Write down anything odd. Items 4–8 are what a reviewer does, so they must all pass before you submit.

---

### Checked and fine

These items were verified in code and need no action:
- The Developer menu (`SettingsCard.swift:284`), test unlock (`ProStore.swift:97-104,127-131`) and the logo long-press (`HomeView.swift:60`) are all behind `#if DEBUG` and absent from Release. The Release config has no `DEBUG` flag.
- The StoreKit config is used only by the Run scheme (`project.yml:86`) and is not a bundle resource, so it does not ship.
- The app icon is a single 1024 × 1024 RGB image with no alpha. The launch screen color exists.
- iPad supports all four orientations with `UIRequiresFullScreen = NO`, which meets the multitasking requirement. iPhone is portrait only.
- No usage descriptions are needed: no camera, microphone, photos or location.
- `ITSAppUsesNonExemptEncryption = NO` is correct.
- Transactions are finished, `Transaction.updates` is observed from launch, refunds and revocations remove Pro, and Ask to Buy shows a pending message and unlocks when approved.
- The game, library and records are saved atomically, and a decode failure falls back to a new game instead of crashing.
- The engine runs off the main thread. Its tasks are cancelled on undo, new game and opponent change.
- 4.2 (minimum functionality) is not a concern: two-player play, five computer levels, puzzles, review, library and clock.

*Sources: Apple required-reason API and privacy manifest docs; Apple auto-renewable subscriptions page; App Review Guidelines 3.1.2 and 5.1.1; Apple upcoming requirements (Xcode 26 / iOS 26 SDK since 28 April 2026); App Store Connect screenshot specifications; TelemetryDeck "Apple's app privacy details" and the SDK's own `PrivacyInfo.xcprivacy` (read from github.com/TelemetryDeck/SwiftSDK, August 2026); Apple DSA trader and Small Business Program pages. All links are inline above.*
