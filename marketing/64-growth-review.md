# 64: growth and monetization review

*Written October 25, 2026. Based on the code on `claude/table-chess-ipad`, the CI screenshots on `ci-shots`, the existing `64-launch-plan.md`, and web research. Numbers from the web are linked. Anything marked **(guess)** is my judgement, not data.*

---

## 1. Verdict in 5 lines

1. **Realistic potential:** €300–500 a month after 12 months if you post consistently and launch well. €2,000+ a month only if one content format keeps going viral or Apple features the app. If you launch and don't promote it, expect under €100 a month.
2. **Why it isn't higher:** chess is a crowded, free category. The median *gaming* subscription app turns only [1.0% of downloads into payers within 35 days](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming), half the all-app median of [2.0%](https://www.revenuecat.com/state-of-subscription-apps). Lichess and Chess.com both offer free pass-and-play.
3. **Single biggest lever:** a repeatable short video made from **real screen recordings with the sound on**: "the most satisfying chess app" (weighted wood sounds, ripples, the king tipping over, gold leaf). It costs nothing to film, shows what is genuinely different about 64 in the first second, and works on iPhone too, which is a much bigger market than iPad.
4. **Single biggest risk:** Pro sells *feel and beauty*, not function, and gaming converts poorly. So you need volume (roughly 1,500 downloads a month for €500 a month), and volume needs you to keep posting. Most solo apps stall when the owner stops posting around week 6.
5. **Before you spend anything on ads,** fix five things in the app (section 2): sound gets muted by the silent switch, the paywall has no Terms/Privacy links (a likely rejection), the purchase button falls below the fold on small iPhones, there is no lifetime option, and nothing asks for a rating.

---

## 2. Product review for growth

### What I looked at

Home, onboarding (3 pages), paywall (`ProCard`), Pro welcome, Learn (144 mate-in-1/2/3 puzzles, 5 free), Library and review, Options, sound and ambience code. I also viewed the iPad Pro 13" and iPhone SE screenshots of home, game, paywall, welcome, review, win and learn.

### What already helps

- **It looks expensive.** The 3D pieces, marble and rosewood boards, gold accents and the review screen (balance graph, `??` and `?!` marks, accuracy) look like a €20 product, not a free ad-supported chess app. That gives you room to price.
- **Sensory moments made for video:** weighted placement sounds, the visible ripple when a piece lands (it reads with the sound off, which matters because App Store previews autoplay muted), the king toppling, the clock press and tick, gold dust on a win. Few chess apps do any of this.
- **Built-in word of mouth:** every friend game puts the app in front of a second person.
- **Honest paywall:** clear prices, "Not now", Restore, Family Sharing already on in the StoreKit config (`familyShareable: true`), and a lovely Pro welcome.
- **Works offline, collects no data, runs on iPhone and iPad.** Note that the old launch plan and the README still say "iPad only". The app supports iPhone (`TARGETED_DEVICE_FAMILY: "1,2"`). Market it on both.

### What hurts (found in the code and screenshots)

| Issue | Where | Why it matters |
| --- | --- | --- |
| **Sound obeys the silent switch** | `AudioManager` uses `.ambient` | Many iPhones sit on silent. Someone who installs 64 after a "satisfying sounds" video hears nothing and feels cheated. The core hook disappears. |
| **No Terms of Use / Privacy Policy links** on the paywall or in Options | `ProCard.swift`, `SettingsCard.swift` | Developers report frequent rejections under guideline 3.1.2 for missing EULA and privacy links in the app *and* the metadata ([Apple forum](https://developer.apple.com/forums/thread/809635), [RevenueCat rejection guide](https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections)). |
| **Purchase button below the fold on small iPhones** | `phonese-12-paywall` screenshot: the card scrolls and "Start free week" is off screen | A buyer has to discover they can scroll. That costs conversions on every small phone. |
| **No lifetime option** | `SixtyFour.storekit` | Chess and board-game players dislike subscriptions. Gaming has the highest lifetime share of any category ([18% of plans sold](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming)). Most of Pro (boards, sets, ambience, levels) is one-time value anyway. |
| **No rating prompt** | no `requestReview` anywhere | A new app with 0 ratings converts badly on its product page. Ratings are cheap to get at happy moments. |
| **"Learn" shows a PRO badge although 5 puzzles are free** | `HomeView` `badge: pro.isPro ? nil : "PRO"` | Free users skip the one feature that builds a daily habit. |
| **Sign in with Apple at the end of onboarding does nothing useful** | `OnboardingView.finale`, `AccountStore` | Games stay on the device either way, so it is a decision with no benefit right before the first game. Without the capability it even shows "isn't available in this build". |
| **The "aha" comes late** | onboarding is 2 watch-only scenes, then sign-in, then home, then a menu | The magic moment is picking up a piece and *hearing* it land. A new user needs about 5 taps to get there. |
| **Paywall headline points at the wrong buyer** | "Everything in 64, for players who want to get better." | The people this app attracts are buying beauty, feel and a nice evening, not improvement. Improvement buyers go to Chess.com. |
| **No measurement** | no analytics | You won't know which paywall entry point converts, or whether people make a first move. |
| **No share moment** | only PGN sharing in Replay | A win or a solved puzzle is the natural "look at this" moment, and right now it leads nowhere. |
| **Copy mismatch with what ships** | only `ambience_rain`, `ambience_fire`, `ambience_night` are bundled; `BotLevel` has **4** levels (Casual, Club, Master, Grandmaster), not 5 | Storm, café, sea and forest are filtered out because their files are missing. Don't promise them in marketing, and say "4 levels" (or add a fifth). |
| **Few puzzles for a subscription** | 144 puzzles total | A keen solver gets through them in a week. "All puzzles" is not a reason to *stay* subscribed. |

### Recommended changes, ranked by impact vs effort

Effort assumes you work with Claude Code on the existing SwiftUI code.

| # | Change | Impact | Effort | When |
| --- | --- | --- | --- | --- |
| 1 | **Add Terms of Use (Apple's standard EULA) and Privacy Policy links** at the bottom of the paywall and in Options ▸ More. Put both URLs in App Store Connect and the description too. | Avoids rejection | 30 min | **Must before launch** |
| 2 | **Sound on, always findable:** (a) add an Options toggle "Play sounds in silent mode", on by default, using `.playback` + `.mixWithOthers` so music from other apps keeps playing; (b) add a small "🔊 Sound on — 64 is made to be heard" line on the first onboarding page. | Very high: protects the core hook | 1–2 h | **Must before launch** |
| 3 | **Pin the paywall's price rows and button** to the bottom of the card and scroll only the feature list, so the button is always visible on an iPhone SE. | High | 1–2 h | **Must before launch** |
| 4 | **Add a lifetime product** (non-consumable `app.sixtyfour.pro.lifetime`) as a third row, plus the entitlement check in `ProStore.refresh()`. See section 3 for prices. | High | ½ day | **Must before launch** |
| 5 | **Make onboarding page 2 interactive:** "Pick up the knight." The user drags a real piece and hears the knock and sees the ripple. Then remove Sign in with Apple from onboarding and end with **"Start playing"**. | High: the aha in about 15 seconds | ½ day | **Must before launch** |
| 6 | **Show the paywall once after onboarding** (dismissible, "Not now" stays). Keep the contextual triggers that already exist (locked boards, levels, hints, review). | High: in subscription apps most trials start on install day **(guess, industry consensus)** | 1 h | **Must before launch** |
| 7 | **Rewrite the paywall copy** (see below), lead with visuals, add "Shared with up to 5 family members" and "Cancel before [date] and pay nothing". | Medium–high | 1–2 h | **Must before launch** |
| 8 | **Ask for a rating** with `requestReview` after a win against 64 or the 3rd solved puzzle, never mid-game, at most 3 times a year (Apple caps it anyway). | High: social proof | 30 min | **Must before launch** |
| 9 | **Change the Learn badge to "5 free"**. | Small but free | 5 min | **Must before launch** |
| 10 | **Minimal privacy-friendly analytics.** [TelemetryDeck](https://telemetrydeck.com/blog/pricing-update-2026/) is Germany-based and free up to 100,000 events a month. Track about 8 events: onboarding done, first move, first game finished, puzzle solved, paywall shown (+ source), trial started, lifetime bought, share tapped. Update the App Privacy answers to match. | High for decisions | 2–3 h | **Must before launch** (or week 1) |
| 11 | **First game review free, then a teaser:** "64 found 3 mistakes in this game. See them with Pro." The review engine already exists. | High: shows the most "pro" feature at the right moment | ½–1 day | Soon after |
| 12 | **Share card:** after a win or a solved puzzle, `ImageRenderer` makes a 9:16 image ("Checkmate in 23 · Club level", board, 64 logo, App Store link). | Medium: a viral loop | ½ day | Soon after |
| 13 | **Free daily puzzle with a streak** on Home. Generate many more puzzles with the existing `tools/puzzles` generator (aim for 365+). | Medium–high for D7 retention and content | 1 day | Soon after |
| 14 | **Localize:** App Store page in German, Dutch, Spanish, French and Portuguese (BR) at launch (metadata only, cheap). App strings soon after: SwiftUI `Text("…")` literals are already localizable, so add a String Catalog. | Medium | 2 h now, 1 day later | Page **before launch**, app soon after |
| 15 | **"Film mode"**: a hidden toggle that hides the pins and panels, enlarges the ripples and frames the board for 9:16. It makes your weekly filming twice as fast. | Medium (indirect) | 2–3 h | Soon after |
| 16 | **iPhone home order:** on a phone, make "Play 64" and "Learn" as prominent as "Play a friend". Phones are used solo more than across a table. | Medium | 1 h | Soon after |
| 17 | **Ship the other ambience scenes** (storm, café, sea, forest) as a Pro update, one at a time. Each gives you an "update" post and an In-App Event. | Medium for retention | 1–2 h each | Later |
| 18 | **Home Screen widget: puzzle of the day.** | Medium: retention and featuring | 1 day | Later |
| 19 | **Record real chess-set sounds** (a wooden set, a quiet room, a phone or a cheap mic, 30 minutes) and replace the layered Kenney samples if testers call them "fake". | Depends on feedback | ½ day | Later (sooner if testers complain) |
| 20 | **VoiceOver move input and Game Center achievements.** Apple's editors value accessibility, and Game Center shows up in Apple's Games app. | Medium for featuring | 1–2 days | Later |

### Paywall copy I'd use

- **Headline:** "Make it yours." **Sub:** "Every board, every set, rain at the window, and a review of every game."
- **Feature order:** boards and sets first, with a row of 4–5 small board swatches (visual), then ambience, game review, Master and Grandmaster, hints, every game kept.
- **Plans:** Yearly (selected, "7 days free"), Lifetime ("Pay once"), Monthly.
- **Footer:** "Shared with your family. Cancel before [date] in Settings and you pay nothing. · Terms · Privacy · Restore"

### The "aha" moment, defined

**Lifting a piece and hearing it land within the first 15 seconds.** For solo users there is a second one: **seeing your own mistakes marked in a review**. Every onboarding and paywall decision should shorten the path to one of these two.

### iPhone vs iPad

- **iPad** is where "across the table" really shines, and it photographs best. It is a much smaller install base than iPhone **(guess; Apple doesn't publish the split)**.
- **iPhone** is where the volume is, and the satisfying/ASMR angle, vs-computer play and puzzles all work there. Make one set of App Store screenshots per device with a different story (section 4).

---

## 3. Monetization

### Subscription, lifetime or one-time?

**Recommendation: subscription + lifetime.** Here is why.

- **A subscription alone is a hard sell here.** Most of Pro is "own it once" value (boards, sets, ambience, stronger levels). Only game review, and later daily puzzles and new scenes, keep giving. Gaming's subscription numbers are the weakest of any category: median D35 download-to-paid [1.0%](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming), year-1 revenue per payer [$11.22](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming). Annual subscribers churn heavily: only [27–28% are still paying after a year](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026).
- **A one-time price alone** gives up the trial, which is your best converter, and gives no recurring income.
- **Both together** let subscription-haters buy, and it is common: subscription + lifetime is the [second most common model (23.2% of apps)](https://www.revenuecat.com/state-of-subscription-apps), and lifetime takes its biggest share in gaming. Magnus Trainer (owned by Chess.com) sells monthly, yearly and lifetime ([App Store listing](https://apps.apple.com/us/app/-/id1097863089)).
- **No hard paywall.** Hard paywalls convert about 5× better per download ([10.7% vs 2.1%](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)), but free friend play *is* your word of mouth. Keep it free.

### Price points

| Product | EUR | USD | Notes |
| --- | --- | --- | --- |
| **Yearly**, 7-day free trial | **€19.99** | **$19.99** | Keep. Below the gaming yearly median of [$24.99](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming). Test €24.99 after 3 months if trial→paid stays above 30%. |
| **Monthly**, no trial | **€3.99** | **$3.99** | Up from 2.99. Mainly an anchor ("Yearly saves 58%"). Gaming monthly median is [$4.99](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming). |
| **Lifetime** | **€39.99** | **$39.99** | About 2× yearly, so it doesn't cannibalize the subscription. |
| **Founder lifetime** (launch only) | **€24.99** | **$24.99** | First 4–6 weeks. Shown honestly: "Launch price until 15 January". Apple has no intro offer for one-time purchases, so you simply schedule a price change in App Store Connect. It also gives you a real deal to post on r/AppHookup. |

**Critique of the old plan's price list** (€14.99 yearly, €29.99 lifetime): too cheap for how premium 64 looks. Low-priced apps also tend to convert *worse* ([1.4% vs 2.8% for high-priced, D35](https://www.revenuecat.com/state-of-subscription-apps)). That is a correlation, not proof that raising prices raises conversion, but it is no argument for going cheap.

**What you actually receive** (Small Business Program, 15%; Apple keeps 15% in the EU too under the [new EU terms from 1 October 2026](https://www.iclarified.com/101814/apple-revises-eu-app-store-terms-replaces-core-technology-fee-with-5-commission)):

- €19.99 yearly in Germany: minus 19% VAT = €16.80, minus 15% = **about €14.30**. Netherlands (21% VAT): about €14.05. US: about $17.
- €39.99 lifetime in Germany: about **€28.55**. Founder €24.99: about €17.85.
- €3.99 monthly in Germany: about **€2.85** a month.

### Trial length

Keep **7 days** at launch. It is a reasonable middle and gives you fast feedback. RevenueCat finds longer trials convert better ([17–32 days: 42.5% median trial→paid; under 4 days: 25.5%](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)), so test **14 days** in month 3 once you have a baseline. Don't go to 3 days.

### Paywall timing

1. Once at the end of onboarding (new).
2. Contextual taps that already exist: locked board, set, level, hint, review, puzzle 6.
3. **After the first finished game against 64:** "Review this game" (1 free review, then the teaser).
4. Home's gold button stays. Never interrupt a game in progress.

### Other levers

- **Family Sharing:** already enabled. *Say it* on the paywall and App Store page. Family is a strong reason to buy an "across the table" app.
- **Regional pricing:** leave Apple's automatic equalization at launch. After 60 days, if India, Brazil, Turkey or Eastern Europe show many paywall views but almost no purchases, cut prices there by 40–60% **(guess at the size of the cut)**.
- **Offer codes for creators and press:** Apple replaced in-app promo codes with offer codes. You can create up to [1 million codes per quarter](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-offer-codes-for-in-app-purchases), one-time-use or custom (e.g. `CHESSCLUB`). Reportedly they now work for one-time purchases too, so verify in App Store Connect that a lifetime offer code is possible.
- **Win-back offer** for lapsed yearly subscribers (for example 50% off the first year) once you have any churn. Set it and forget it.
- **No weekly plan, no ads.** Both clash with a premium brand.

---

## 4. Positioning and App Store page (ASO)

### Positioning

- **Brand line (keep):** "Chess, across the table."
- **Discovery angle (add):** "The most satisfying chess app." Use it in videos, screenshot 1 and the preview video.
- **Proof points, all true:** hand-modeled 3D pieces; heavier pieces sound heavier; plays offline; 4 computer levels; checkmate puzzles; every game reviewed (Pro); no ads, no account, no data collected.
- **Don't claim:** "the only pass-and-play app" (Lichess has an [over-the-board mode with a clock](https://apps.apple.com/app/id968371784), Chess.com has [Pass and Play](https://chess.com/forum/view/help-support/feature-request-offline-game-with-2-human-players)), storm/café/sea scenes, or 5 levels.

### Name, subtitle, keywords

"64" alone can't be found in search, so the name must contain "chess". Apple indexes the name, subtitle and keyword field. Words aren't counted twice, so never repeat a word across the three.

**English (US and UK), recommended:**
- **Name (26/30):** `64: Chess Across the Table`
- **Subtitle (29/30):** `2 Player Board Game & Puzzles`
- **Keywords (99/100):** `pass,play,offline,friend,clock,timer,mate,tactics,trainer,wood,asmr,ipad,family,couple,ai,bot,learn`

**Alternative subtitle** to A/B test with Product Page Optimization: `Chess for Two, Face to Face`. If you use it, move "player,board,game,puzzles" into the keyword field and drop "family,couple,learn".

**German (de-DE):**
- **Name:** `64: Schach am Tisch`
- **Subtitle:** `Zu zweit, offline & Rätsel`
- **Keywords (99):** `brettspiel,zwei,spieler,offline,freund,uhr,matt,taktik,training,holz,familie,lernen,rätsel,computer`

**Dutch (nl-NL):**
- **Name:** `64: Schaak aan tafel`
- **Subtitle:** `Met z'n tweeën, offline`
- **Keywords (99):** `schaak,bordspel,twee,spelers,offline,vriend,klok,mat,tactiek,training,familie,leren,puzzel,computer`

**Tip:** most storefronts also index a second language (US indexes Spanish (MX), for example), which [roughly doubles your keyword space](https://appfigures.com/resources/guides/extend-keyword-list). Check [Asodesk's cross-localization table](https://help.asodesk.com/app-store-localizations) for which locales Germany and the Netherlands index, and fill those with *different* keywords.

### Category

**Games ▸ Board**, with **Puzzle** as the second game subcategory. Top charts in "Board" are far less crowded than "Games" overall, so a few hundred downloads on a good day can put you in the top 50 of Board in Germany or the Netherlands **(guess)**. Chart presence then brings more downloads.

### Screenshot storyboard

Captions short, large, cream on brown, max 5 words. Screenshots with only one or two words of caption tend to read better on small phones. Whether Apple indexes caption text for search is [disputed](https://appscreenshotstudio.com/blog/app-store-screenshots-vs-description-2026-aso-trade-off), so write for people, not the algorithm.

**iPhone (6.9" set):**

| # | Caption | Image |
| --- | --- | --- |
| 1 | **Chess you can hear.** | Close-up of a queen landing on marble with the ripple visible, gold accents |
| 2 | **Heavier pieces sound heavier.** | Rook mid-air with its shadow, ripple below, a small "🔊" |
| 3 | **Play the person in front of you.** | Pass-and-play board, both panels, "You / Them" |
| 4 | **Or beat 64. Four levels.** | Vs-computer game, level pills (Casual → Grandmaster) |
| 5 | **Find the checkmate.** | Learn screen, Mate in 2 |
| 6 | **See every mistake.** | Review: balance graph, `??` chips, accuracy |
| 7 | **The king falls. Gold leaf.** | Win screen with the toppled king |
| 8 | **Ten boards. Three sets.** | Grid of Marble, Rosewood, Midnight, Ebony, Salon |
| 9 | **Rain at the window.** | Ambience tiles over a dark board |
| 10 | **No ads. No account. Offline.** | Logo on brown, "Shared with your family" |

**iPad (13" set):** same idea, but lead with "Chess, across the table." Screenshot 1 is the full board seen from above with both players' panels. Optionally add one *real* photo of two pairs of hands over an iPad as a frame. Don't use AI-generated people on the App Store page: it misleads and risks review problems.

### Preview video (15–25 s)

Apple requires app previews to use [footage captured from the app](https://developer.apple.com/app-store/app-previews/), so this is pure screen recording. It autoplays **muted**, so the ripples and motion must carry it:

> 0–3 s macro of a piece dropping with its ripple · 3–7 s capture, piece flies to the tray · 7–11 s clock running low, tap, tick · 11–15 s checkmate, king topples, gold leaf · 15–20 s board styles changing · end on the logo.

Make an iPad version that opens on the full table.

### Custom product pages

You can now publish up to [70 custom product pages and attach keywords to them for organic search](https://adapty.io/blog/custom-product-pages-app-store/). Make 2 at launch:

- **"Satisfying"**: link it from TikTok and Instagram bios.
- **"Chess for two"**: for Apple Ads and the keywords `pass,play,friend`.

### What makes Apple's editors feature it

Apple asks for a nomination at least [two weeks ahead, preferably three, and up to three months for wider consideration](https://developer.apple.com/app-store/getting-featured) (submit it under App Store Connect ▸ Featuring ▸ [Nominations](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring)). What helps, from Apple's stated criteria ([Apple](https://developer.apple.com/app-store/getting-featured), [mobilegamer.biz](https://mobilegamer.biz/apples-app-store-team-reveal-their-tips-and-tricks-for-getting-featured/)) and my judgement:

- **Craft story:** solo developer in Europe; a rules engine written from scratch and perft-verified; ray-marched 3D pieces; foley-layered sounds. Editors love a maker story. Write it in 5 sentences in the nomination.
- **iPad excellence:** every orientation, Split View, Stage Manager. Already done; say so.
- **Accessibility:** VoiceOver move input is missing today. Adding it (item 20) is a strong featuring argument.
- **Localization** into several languages.
- **Timing hooks:** "Holiday games to play together" (December) and "New Year, new habit" puzzles (January). Nominate each update separately ("New: daily puzzle", "New: storm ambience") with an In-App Event.
- **No dark patterns:** the honest paywall is a plus.

---

## 5. Viral content engine

### What changed from the old plan

The first 10 Reels in `64-launch-plan.md` all opened on AI clips of people. You judged those clips "slop", and you were right: faces and hands are where AI video gives itself away. Those posts also sell the *situation* ("date night"), which anyone could film with any chess app. **Sell what only 64 has: the sound and the motion.** Real screen recordings carry that, and they cost nothing.

There is proof that an app can grow from one repeated demo format. A third-party breakdown credits ClipTone with [about 55M views across 51 near-identical TikToks](https://playkit.beehiiv.com/p/ringtone-app) (unverified). Touch Retouch reached No. 1 in paid apps in several countries from [one creator video](https://omr.com/de/touch-retouch-tiktok/). Most accounts never get there, so plan for steady and treat viral as a bonus.

Chess has an audience on short video: Chess.com's TikTok has about [2.25M followers and 154M views a year](https://socialpruf.com/tiktok/chess). But I found **no data on "chess ASMR" as a format**. It is a reasonable bet, not a proven one.

### Six repeatable formats

1. **Sound close-up (core, 7–12 s):** macro screen recording, one move or a capture, sound only, one line of text. Loops well.
2. **"Satisfying" compilation (15–25 s):** 6 cuts: drop, capture, castle, clock tick, king topples, gold leaf.
3. **Puzzle of the day (10 s + comments):** freeze on a mate-in-2. "Answer in the comments." Reveal the solution in a follow-up the next day. Drives comments and follows.
4. **Real hands, real table (owner-filmed):** a phone on a tripod overhead, two real people playing on an iPad. Faces optional. Ask a friend, a partner or family. Use only *real* people here.
5. **Challenge series:** "Day 1 of trying to beat Grandmaster", "Can my dad beat Casual?" Series bring people back.
6. **Maker story (voiceover over screen):** "I spent 3 months making chess pieces sound real." Build-in-public posts get shared outside chess circles.

### 15 specific posts

| # | On-screen hook | What to film | Format |
| --- | --- | --- | --- |
| 1 | "Chess, but every piece has its own sound 🔊" | Pawn, knight, rook, queen dropped one after another on the same square, macro | 1 |
| 2 | "The most satisfying chess app?" | 6-cut compilation ending on gold leaf | 2 |
| 3 | "How it feels to resign in this app" | Tap resign, own king tips over and bounces, slow | 1 |
| 4 | "Mate in 2. 90% get it wrong." *(only if your comments support the claim; otherwise "Can you find it?")* | Puzzle frozen 3 s, then an end card | 3 |
| 5 | "Rain, fire, and a slow game of chess" | 30–45 s calm game with rain ambience (long watch time) | 2 |
| 6 | "POV: 10 seconds left on the clock" | Clock tick + presses, fast moves, flag falls or mate | 1 |
| 7 | "My girlfriend said she's 'not really a chess person'" | Real overhead hands, couple game, her checkmate, king topples | 4 |
| 8 | "Day 1 of trying to beat Grandmaster" | Screen recording, honest commentary as captions, the loss | 5 |
| 9 | "64 reviewed my game. I'm not okay." | Review screen scrolling through `??` blunders, balance graph diving | 5 |
| 10 | "Which board would you play on?" | 10 boards, 1 second each, same opening position | 2 (or photo carousel) |
| 11 | "I made the knight sound like real wood" | Voiceover: layering 3 recordings; waveform; final drop | 6 |
| 12 | "Capture sounds, ranked" | 4 different capture clacks, viewers vote in comments | 1 |
| 13 | "Phone down. Board up." | Real café or kitchen table, two pairs of hands, iPad flat | 4 |
| 14 | "The final move hits different" | Checkmate move in slow motion, gold leaf falls, hold 2 s | 1 |
| 15 | "Chess with grandpa, Sunday edition" | Real family, hands only if preferred, the board between them | 4 |

**Rules for every post:**

- Text in the first frame.
- Sound is the app's own audio, recorded internally via iOS screen recording.
- Under 15 s unless it is an ambience piece.
- No App Store link in the video; "64 Chess" in the caption and the link in bio (pointing to the custom product page).
- Upload the sound-only clips as an **original sound named "64 chess sounds"**, so others can reuse it.

### Filming kit (about €0–30)

- Your iPhone or iPad's own screen recording, with "Film mode" (item 15) once built.
- A €15–25 phone tripod with an overhead arm for real-hands shots.
- A desk lamp for warm light.
- CapCut free for editing.
- A plain dark wood table or a cheap wood-look surface.

### Cadence

- **Weeks −3 to 8:** 4 posts a week, the same video on TikTok, Instagram Reels and YouTube Shorts. That is 12 uploads, made from 4 videos.
- **After week 8:** 3 a week; 2 a week as the minimum. Consistency beats volume: three good videos a week, every week, beat seven rushed ones followed by silence ([Ocoya](https://blog.ocoya.com/blog/tiktok-posting-frequency)).
- **What to optimize:** watch-through, replays, shares and comments, not likes ([SEM Nexus playbook](https://semnexus.com/tiktok-organic-and-paid-a-2026-app-growth-playbook), a vendor view).

### The weekly 1–2-hour workflow (after the first month)

| Step | Time | What |
| --- | --- | --- |
| Sunday: record | 30 min | 3–4 screen recordings in one sitting (Film mode, sound on). One real-hands shot every 2 weeks. |
| Sunday: edit | 40 min | 4 clips from CapCut templates you saved in month 1 (same fonts, text spot, end card). |
| Sunday: schedule | 15 min | TikTok's built-in scheduler + Meta Business Suite (free) + YouTube Studio. |
| Wednesday: review | 15 min | Look at 3-second hold and average watch time. Reply to comments. Note which hook won. |
| Monthly: remake | 30 min | Remake the month's best video with 3 new hooks. |

The **first 4 weeks will take 3–5 hours a week**: setting up templates, finding which hook works, and replying to every comment in the first hour. It only becomes 1–2 hours once the formats are fixed.

### Higgsfield credits: use them sparingly

- **Use them for:**
  - Faceless product B-roll as 1–2 s openers or backgrounds (an iPad on a walnut table with rain light on the window, a slow dolly).
  - Candid *still* images for photo-mode carousels, which you liked.
  - Seasonal visuals (a fireplace at Christmas).
  - At most 10–15% of posts.
- **Don't use them for:** AI video of people or hands, anything on the App Store page or preview, or "reactions". Label AI content on TikTok and Instagram; both platforms ask for it.
- **Optional:** Higgsfield has a virality predictor tool. Only use it on finished edits when choosing between two cuts, and only if it is cheap in credits. Your own 3-second-hold data is free and more reliable.

---

## 6. Paid and partnerships

### The math that decides paid ads

Proceeds per download ≈ download-to-paid rate × value per payer.

- **Value per payer:** with the price list above and a 60% yearly / 25% lifetime / 15% monthly mix, it is about **€18** over time (one renewal included).
- **At 1% conversion** (gaming median): **about €0.19 per download**.
- **At 2%:** **about €0.37**.
- **At 3.5%:** **about €0.65**.

Apple Ads cost about [$1.34 per download in Germany and $1.07 in the Netherlands](https://adapty.io/blog/markdown/apple-ads-benchmarks-2026.md) across all categories (games usually cost more). Meta and TikTok iOS installs typically cost [$2–4+ in tier-one markets](https://segwise.ai/blog/cpi-ipm-roas-benchmarks-optimizing-ad-spend.md).

**Conclusion:** paid installs lose money unless your conversion is well above the median. **Don't run paid ads before you know your own conversion.**

### Apple Ads: the only paid channel worth testing, and only later

- **Start when:** at least 4 weeks live, ≥ 20 ratings averaging ≥ 4.5, and App Store Connect shows download-to-paid ≥ 2.5%. Apple's [March 2026 analytics update](https://9to5mac.com/2026/03/25/apple-announces-major-update-to-analytics-in-app-store-connect/) adds cohorts and a peer-group download-to-paid benchmark, so you can read this without an SDK.
- **Setup:** Apple Ads Advanced, exact match only:
  - EN: `chess for two`, `2 player chess`, `chess offline`, `chess board`, `chess clock`, `chess puzzles`
  - DE: `schach zu zweit`, `schach offline`
  - NL: `schaken offline`
  - Germany, Netherlands, UK, US. **€5–10 a day**, 14 days, max CPA €1.00.
- **Kill if:** after 14 days or 300 taps, cost per trial start > €4, or proceeds per download from Ads < 80% of the CPA. Brand-keyword defence ("64 chess") only if a competitor bids on your name.
- **Apple Ads Basic** (pay per install, [up to $10,000/month cap](https://ads.apple.com/app-store/help/apple-ads-basic/0039-promote-an-app-with-basic)) is simpler but gives less control. Advanced is fine at this size.

### Meta and TikTok ads

**Skip them in the first 90 days.** The one exception: if an organic post crosses 100k views, boost *that exact post* with €30–50 (TikTok Promote / Instagram Boost) to followers-like audiences in DE/NL/UK. Stop if cost per profile visit is above €0.15 **(guess at threshold)**.

### Creator outreach

**Who:**

- 20 micro-creators with 5k–100k followers in three groups:
  - chess (find them via [Modash's chess TikTok lists](https://www.modash.io/find-influencers/tiktok/chess/male));
  - **"cozy/aesthetic iPad" and desk-setup creators**, often a better fit than chess players;
  - ASMR / satisfying creators.
- German and Dutch creators first: smaller, more likely to answer, and your home markets.

**Offer:** a free lifetime via offer code (or a free year), no obligation to post. For micro-creators who reply positively, a €50–150 paid post is reasonable. Disclosure must be clear (#ad; in Germany "Werbung/Anzeige").

**Template (keep it short; personalize the first line):**

> Hi [name], your video on [specific video] — the [specific detail] — is the reason I'm writing.
>
> I'm a solo developer in [city] and I just launched **64**, a chess app built around how chess *feels*: hand-modeled pieces, wood sounds where a queen lands heavier than a pawn, a king that actually tips over when you resign. It's made for playing face to face on one iPad or iPhone.
>
> I'd love to give you 64 Pro for life, here's a code: [CODE]. No obligation to post anything. If you do make something and want clips, boards or sound files, I'll send whatever helps.
>
> Thanks either way,
> [first name] · [App Store link] · [15-second preview link]

Follow up once after 7 days. Expect a 10–20% reply rate and 2–5 posts from 20 messages **(guess)**.

### Communities: give first, link second

| Where | Approach |
| --- | --- |
| **r/chess** | Read the rules first; I couldn't fetch them, and big subs restrict self-promotion. Post *content* (a puzzle, the "heavier pieces sound heavier" clip) and answer "what app is this?" in comments. Never more than once a month. |
| **r/AppHookup** | Post the Founder lifetime price at launch. This is exactly what the sub is for. |
| **r/iosgaming, r/ipad, r/SideProject, r/indiedev** | "I built this" posts with the maker story and a short clip. Reply to everything. |
| **Hacker News "Show HN"** | The tech story: an engine written from scratch and perft-verified, ray-marched pieces, foley sound layering. Link a short write-up page, not the store. One shot; post on a weekday morning US time. |
| **Product Hunt** | Low effort, small but real reach; launch on a Tuesday–Thursday. |
| **Apple press (DE/NL)** | Short pitch + press kit to [iCulture](https://www.iculture.nl) (NL), iPhone-Ticker, Mac & i / Macwelt (DE), MacStories and 9to5Mac (EN). Local "solo developer from [city]" angle. |
| **Chess clubs** (Schachverein / schaakclub) | Email 10 local clubs: a free lifetime code for the club iPad, and a poster for the club night. Ask if you may film a game (real people, with consent). |
| **Chess cafés / board-game cafés** | Table card with a QR code (to the custom product page) + a free lifetime for the café iPad. Small reach, but a great real filming location. |

---

## 7. 90-day plan (launch target: early December 2026)

**Why December:** new iPads and iPhones are unwrapped at Christmas, families sit at tables, and Apple runs "play together" collections. Featuring needs at least 3 weeks' notice, so the dates below are tight but doable.

| Week | Dates | Checklist |
| --- | --- | --- |
| **−5** | Oct 26–Nov 1 | Join the Apple Developer Program (€99; identity checks can take days). Register as a business (Gewerbe in DE / KVK in NL) and declare EU trader status, which shows your address publicly on the store. Write and host the privacy policy and support page (free Carrd/Notion). Start the app fixes from section 2. |
| **−4** | Nov 2–8 | App Store Connect: app record, subscription group, lifetime product, new prices, Paid Apps agreement, **Small Business Program**. Finish the must-before-launch app changes. TestFlight to 20–50 people (friends, a chess club, r/TestFlight). Create the TikTok/IG/YouTube accounts. Record 20 screen-recording clips. |
| **−3** | Nov 9–15 | **Submit the featuring nomination** (launch Dec 1, holiday angle, maker story). Fix TestFlight feedback, especially "is the sound good?". Post 4 times ("coming December"); start the hook test. |
| **−2** | Nov 16–22 | Screenshots, preview video, localized metadata (EN, DE, NL, ES, FR, PT-BR). 2 custom product pages. Press kit page. Line up 20 creator names. Post 4 times. |
| **−1** | Nov 23–29 | Submit to App Review by Nov 24 (allow for a rejection round). Set it to manual release. Prepare r/AppHookup, Product Hunt and Show HN drafts. Post 4 times. |
| **0** | Nov 30–Dec 6 | **Launch Dec 1.** Founder lifetime €24.99. Ask every TestFlight tester to rate (on the real store build). Send creator emails. Post on Reddit, Product Hunt and Show HN (spread over 3 days). Pitch press. Post daily this week. |
| **1** | Dec 7–13 | Read the first numbers (table below). Reply to every review. Post 4 times. Nominate the "daily puzzle" update for January. |
| **2** | Dec 14–20 | Ship "soon after" items 11–12 (first review free, share card). Christmas content: "chess with family this Christmas". Follow up with creators. |
| **3** | Dec 21–27 | Mostly offline (App Review slows over the holidays). Scheduled posts only. Watch Christmas Day downloads. |
| **4** | Dec 28–Jan 3 | New Year content. **Day-30 decision** (below). |
| **5–6** | Jan 4–17 | Founder price ends Jan 15; post about it once, honestly. Ship the daily puzzle + streak (+ an In-App Event "New Year Puzzle Week"). Localize app strings. |
| **7–8** | Jan 18–31 | Remake the top 2 formats with new hooks. If the Apple Ads criteria are met, start the 14-day test. Test a paywall variant (headline or plan order). |
| **9–10** | Feb 1–14 | Valentine's content ("date night, but chess"). Release one new ambience scene + featuring nomination. Test a 14-day trial if trial→paid ≥ 30%. |
| **11–12** | Feb 15–28 | Widget (if time). Regional price review. **Day-90 decision** (below). |
| **13** | Mar 1 | Write a one-page "state of 64": numbers, best formats, what to automate. |

### Metrics to track (weekly, in one spreadsheet)

Benchmarks are from the RevenueCat gaming report unless marked otherwise.

| Metric | Where | Target | Act if below |
| --- | --- | --- | --- |
| Product page views → downloads | App Store Connect | ≥ 25% **(guess)** | < 15%: redo screenshot 1–3 and the icon |
| Onboarding completed | TelemetryDeck | ≥ 85% | < 75%: shorten it |
| First move made (day 0) | TelemetryDeck | ≥ 80% | < 65%: start new users straight on a board |
| D1 / D7 retention | App Store Connect | ≥ 25% / ≥ 8% **(guess, typical casual games)** | D7 < 5%: daily puzzle becomes urgent |
| Download → trial | ASC / TelemetryDeck | ≥ 5% (gaming median [4.4%](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming)) | < 2.5%: paywall seen too rarely; check sources |
| Trial → paid | App Store Connect | ≥ 25% (gaming median [25.0%](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming)) | < 15%: Pro's value is unclear; test the first-review teaser and copy |
| Download → paid, D35 (incl. lifetime) | App Store Connect (peer benchmark) | ≥ 2% | < 1%: fix conversion before chasing downloads |
| Lifetime share of purchases | App Store Connect | 20–40% | > 60%: lifetime is too cheap vs yearly |
| Video 3-second hold / average watch % | TikTok / IG Insights | ≥ 60% / ≥ 50% on < 15 s clips | Below: change the first frame, not the rest |
| Views per post (median) and top post | Platforms | Rising month on month | Flat for 4 weeks: change format or angle |
| Profile → link taps | Platforms | Track only | — |

### Decision points

- **Day 30:**
  - Downloads < 300 *and* no post above 10k views after 16+ posts: switch the lead angle (satisfying ↔ couples/family) and rewrite hooks.
  - Trial→paid < 15%: work on the paywall and Pro value before anything else.
- **Day 60:** if D35 download→paid ≥ 2.5% and ratings ≥ 4.5, run the Apple Ads test. Otherwise don't.
- **Day 90:**
  - **On track** (≥ €150/month in proceeds and rising): keep the 1–2 h weekly workflow; plan one Pro update per quarter.
  - **Stalled** (< €50/month, no format above 50k views): switch to **maintenance mode**. Post once a week, keep ASO tidy, ship the annual iOS update, and stop spending. 64 still earns a small passive trickle from search.

---

## 8. Passive-income reality check

### The model

**Assumptions (all in EUR, after VAT and Apple's 15%):**

- New payers split 60% yearly (€14.50), 25% lifetime (€21 blended founder/regular), 15% monthly (€2.20/month, 15% monthly churn).
- 28% of yearly subscribers renew ([RevenueCat](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)).
- Figures are **monthly cash proceeds** (yearly plans pay up front), not "MRR".
- Downloads include everything: organic search, social, press.

| Case | Downloads/month | Download→paid | Month 6 proceeds | Month 12 proceeds | Total by month 12 |
| --- | --- | --- | --- | --- | --- |
| **Pessimistic:** launch, little promotion | 300 flat | 1.0% (gaming median) | ~€45 | ~€50 | ~€550 |
| **Base:** consistent posting, modest featuring | ramps 400 → 1,500 | 2.0% (all-app median) | ~€345 | ~€470 | ~€4,000 |
| **Optimistic:** one viral moment (8k downloads in month 3) + featuring + a format that keeps working | ramps 1,500 → 5,000 | 3.5% | ~€1,900 | ~€2,700 | ~€26,000 |

Context: only [17% of new subscription apps reach $1k monthly revenue within two years; 4.6% reach $10k](https://www.subscriptioninsider.com/article-type/news/revenuecat-data-shows-subscription-app-growth-concentrating-at-the-top). Gaming does a bit better at [20% and 8.9%](https://www.revenuecat.com/state-of-subscription-apps-2026-gaming). A similar generic chess app from a Dutch publisher is estimated at [100k+ downloads but only ~$7k revenue a month](https://adapty.io/paywall-library/chess-offline-board-game) (third-party estimate, ad- and hint-based). Downloads alone don't make money; conversion does.

### What has to be true

Downloads needed *every month* for steady-state monthly proceeds, by conversion rate (proceeds per download at 1% / 2% / 3.5%: €0.19 / €0.37 / €0.65):

| Goal per month | at 1% | at 2% | at 3.5% |
| --- | --- | --- | --- |
| **€500** | ~2,700 (90/day) | ~1,350 (45/day) | ~770 (25/day) |
| **€2,000** | ~10,800 (360/day) | ~5,400 (180/day) | ~3,100 (100/day) |
| **€5,000** | ~27,000 (900/day) | ~13,500 (450/day) | ~7,700 (255/day) |

**In plain words:**

- **€500/month** needs about 45 downloads a day at a median conversion. Realistic with good ASO plus steady posting.
- **€2,000/month** needs about 180 a day. That takes a working content format *and* above-median conversion, or a lasting top-chart position in Board games.
- **€5,000/month** needs several hundred a day. That is a hit, not a plan.

### Unavoidable ongoing work, even in "passive" mode

| Task | Time | Why |
| --- | --- | --- |
| Annual iOS/Xcode update | 1–3 days per year | Apple raises the minimum SDK each spring, and new iOS versions break things. |
| Support email and review replies | 30–60 min/week | Refund questions, "how do I restore", bug reports. Replies lift ratings. |
| Content | 1–2 h/week (or 30 min in maintenance mode) | Stop posting and downloads fall back to the search baseline within weeks **(guess)**. |
| Developer Program renewal, business admin, tax | a few hours a quarter | €99/year. Income tax and, depending on turnover, VAT returns on Apple's commission. Ask a Steuerberater (DE) or boekhouder (NL) once at the start. |
| One meaningful update per quarter | 1–2 days | A new board, scene or puzzle pack keeps subscribers and gives featuring and press hooks. |

---

## 9. Top 10 next actions (in order, each under a day)

1. **Join the Apple Developer Program** and register your business (Gewerbe/KVK). Everything else waits on this.
2. **Put up a privacy policy + support page** (Carrd/Notion) and add Terms + Privacy links to the paywall and Options (fix 1).
3. **Fix the sound:** a "Play sounds in silent mode" toggle (default on) and a sound-on line in onboarding (fix 2). Test with 3 people on silent iPhones.
4. **Pin the paywall button on small iPhones, rewrite the paywall copy, and add the lifetime product** (fixes 3, 4, 7). Set the prices: €19.99 yearly with trial / €3.99 monthly / €39.99 lifetime, Founder €24.99.
5. **Make onboarding touchable** ("Pick up the knight"), remove Sign in with Apple from it, show the paywall once at the end, and change the Learn badge to "5 free" (fixes 5, 6, 9).
6. **Add the rating prompt and TelemetryDeck's 8 events** (fixes 8, 10). Update the App Privacy answers.
7. **App Store Connect setup:** products, Small Business Program, TestFlight to 20–50 testers. Ask them one question: "Does the sound feel real?"
8. **Submit the featuring nomination** for a December 1 launch, with the maker story, iPad craft and holiday angle. Do it at least 3 weeks before launch.
9. **Film day:** 20 screen-recording clips with sound, build 3 CapCut templates, and schedule the first 8 posts (formats 1–3 from section 5).
10. **Build the App Store page:** name/subtitle/keywords in EN/DE/NL, 10 iPhone + 10 iPad screenshots from the storyboard, the muted-friendly preview video, and 2 custom product pages. Submit for review by November 24.

---

### Corrections to `64-launch-plan.md`, for the record

- "iPad only" is out of date: the app runs on iPhone. Market and screenshot both.
- Its conversion assumption (2–5%, about $1.50–2.00 per subscriber per month) is optimistic for a game. Plan on 1–2% and about €15–18 per payer over time.
- Its Meta test (€300–500 at €2–6 per install) would lose money at those conversion rates. Don't run it until conversion is proven.
- Its €14.99 yearly / €29.99 lifetime prices are below what the product's look supports, and the lifetime is too close to the yearly price.
- Its first 10 Reels rely on AI people. Replace them with real screen recordings and real hands. Keep AI for faceless B-roll and stills.
- Missing from it, now covered here: the silent-switch problem, compliance links, the rating prompt, measurement, the featuring nomination, localization, and the ASMR/sound angle built on the newer features.
