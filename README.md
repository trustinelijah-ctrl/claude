# Human Food

*Eat like a human.* A premium, minimalist SwiftUI food scanner. Point it at a barcode and get a **0–100 score**, a plain-language verdict, the ingredients and nutrients decoded, and **healthier swaps**. Grocery mode ranks a whole basket at once.

The design takes after **Scout** (a camera-first home with Barcode / Label / Grocery modes, a prominent score, collapsible "good / worth knowing" sections and a "healthier alternatives" section). It combines the best parts of Yuka (additive tiers, alternatives), Bobby Approved (ingredient red flags), Fig (a personal avoid list) and Olive (AI explanations). Every score is built on whole-food, plant-forward research (Campbell, Pollan, Greger, NOVA).

## Features

- **Instant scan** — VisionKit barcode scanner, with a breathing viewfinder that snaps and flashes on lock.
- **The reveal** — the ring sweeps while the serif numeral counts up with rising haptic ticks. The colour moves through the tiers, then locks with a bloom. Good scores burst into leaves, and 85+ scores get stamped with the **HUMAN FOOD** seal. Then a toast: *"Food #27 decoded · 5-day streak"*.
- **Score 0–100** — deterministic and explainable, computed on the device ([docs/SCORING.md](docs/SCORING.md)).
- **Our take** — a short AI-written verdict, generated **once per product for all users** and cached. It falls back to a built-in writer when offline.
- **What's good / Worth knowing** — every point added or removed, with its reason. Tap a row for the detail.
- **Nutrition & ingredients** — traffic-light nutrients, the full ingredient list, additive chips.
- **Healthier swaps** — real products from the same category that score at least 8 points higher, plus generic whole-food ideas.
- **Grocery mode** — sweep 2–12 items. The tray fills with score chips, then *Rank* reveals your basket from best pick to "swap first", with one easy upgrade.
- **Label mode** — for products missing from every database. Snap the ingredients (and optionally the nutrition panel), AI reads it, and it's added for everyone.
- **History** — offline cache with search, filters (Great picks / To swap), favourites, stats and a daily streak.
- **Settings** — Plant-forward or Flexible scoring lens, allergen avoid list with warnings, haptics, methodology, disclaimer, Open Food Facts attribution.
- **Safe language everywhere** — no brand names in generated text, no harm words, everything framed as opinion ([docs/SAFE_LANGUAGE.md](docs/SAFE_LANGUAGE.md)).

## Is AI-per-scan too expensive? No — here's the design

| Piece | Where | Cost |
|---|---|---|
| Product data (4M+ products) | [Open Food Facts](https://world.openfoodfacts.org), fetched directly by the phone | Free |
| Score 0–100 | On device (`ScoringEngine`) | Free, instant |
| Healthier alternatives | OFF search + the same on-device scorer | Free |
| Written verdict | Gemini via the backend, **once per product, cached for everyone** | ≈ $0.001–0.005 per *distinct* product |
| Missing product | Gemini vision reads the label once, then stores it for everyone | ≈ $0.01 per new product |

AI cost grows with the number of *distinct* products, not with users or scans, and a daily cap puts a hard ceiling on it. With no backend configured the app still works fully, using the local verdict writer. Details in [backend/README.md](backend/README.md).

## Run it

Requirements: **Xcode 16+**, iOS 17+ device (the simulator has no camera; type a barcode instead, and DEBUG builds include sample barcodes).

```bash
open HumanFood.xcodeproj        # set your Team under Signing, then Run on an iPhone
```

To enable AI verdicts:

1. Deploy the backend ([backend/README.md](backend/README.md)) and put your Gemini key there as a secret.
2. `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and fill in `HF_BACKEND_HOST` + `HF_BACKEND_ANON_KEY`.

For quick prototyping only, you can instead set `HF_GEMINI_DEV_KEY` (DEBUG builds only, no shared cache). Don't ship it.

If the project won't open in your Xcode version, regenerate it: `brew install xcodegen && xcodegen` (uses `project.yml`).

## Project layout

```
HumanFood/
  App/              HumanFoodApp, RootView
  DesignSystem/     Theme tokens, haptics, ScoreRing, ParticleBurst, shared components
  Models/           Product, ScoreResult, Verdict, ScanRecord (SwiftData)
  Scoring/          ScoringEngine, AdditiveCatalog
  Services/         OpenFoodFactsClient, VerdictService (+ backend / Gemini), AlternativesService,
                    LocalVerdictWriter, SafeLanguage, Preferences, AppServices
  Features/
    Scanner/        Camera home, modes, viewfinder, label capture, manual entry
    Result/         ScoreHero reveal, result screen, sections
    Grocery/        Basket, tray, ranking podium
    History/        History list and stats
    Settings/       Settings and "How we score"
    Onboarding/
backend/supabase/   Postgres migration + Edge Function (verdict cache, label reading, daily budget)
docs/               SCORING.md (research + rules), SAFE_LANGUAGE.md
```

## Roadmap ideas

- App icon and custom typeface (the design currently uses SF Pro and New York).
- "Report a problem" flow for data corrections.
- Paywall (e.g. unlimited Grocery mode or label reads) with StoreKit 2.
- Shelf mode (scan several barcodes on a shelf and rank them in place — the grocery ranking engine is already there).
- Localisation: verdicts are already cached per language.

## Data & licences

Product data © Open Food Facts contributors, [ODbL](https://opendatacommons.org/licenses/odbl/1-0/). Product images are CC BY-SA. Scores are Human Food's opinion, not medical advice.
