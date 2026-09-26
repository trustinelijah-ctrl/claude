# The Human Food score

One number from **0 to 100**, computed **on the device** with the same published rules for every product. AI never sets the score — it only writes the explanation afterwards. That keeps the score instant, free, consistent and defensible.

| Tier | Range | Phrase shown |
|---|---|---|
| Excellent | 85–100 | Enjoy freely (+ "Human Food" seal) |
| Good | 70–84 | A solid everyday pick |
| Fair | 50–69 | Fine now and then |
| Limit | 30–49 | Best kept occasional |
| Rarely | 0–29 | Worth swapping when you can |

Source: `HumanFood/Scoring/ScoringEngine.swift` (rules) and `AdditiveCatalog.swift` (additive tiers).

## Philosophy — what the research agrees on

The app is built around a **whole-food, plant-predominant** view of eating. The main voices you mentioned:

- **T. Colin Campbell** — *The China Study* (2005) and *Whole* (2013). (Both books are by the same author.) Argues for whole plant foods over reductionist nutrient-counting, and for limiting animal protein; his lab work on casein is why dairy lowers the score.
- **Michael Pollan** — *In Defense of Food*: "Eat food. Not too much. Mostly plants." Our "short, recognisable ingredient list" and "processing first" rules come straight from this.
- **Michael Greger** — *How Not to Die* and the Daily Dozen: beans, whole grains, fruit, vegetables, nuts and seeds every day.
- **Caldwell Esselstyn** — whole-food plant-based, no added oils → small penalty for refined oils.
- **Chris van Tulleken** — *Ultra-Processed People*; **Carlos Monteiro** — the NOVA classification.

Evidence the rules lean on:

| Rule | Evidence |
|---|---|
| Processing is the baseline | NOVA (Monteiro et al.). NIH inpatient RCT (Hall et al., *Cell Metab* 2019): an ultra-processed diet led to ~500 kcal/day more eating and weight gain versus unprocessed. BMJ umbrella review (Lane et al., 2024) links ultra-processed food exposure to many adverse outcomes. |
| Sugar | WHO (2015): keep free sugars < 10% of energy, ideally < 5%. |
| Salt | WHO: < 5 g salt per day for adults. |
| Fibre bonus | Reynolds et al., *Lancet* 2019: 25–29 g/day fibre and whole grains associated with lower mortality. Fibre exists only in plants. |
| Processed & red meat | IARC Monographs vol. 114 (2015): processed meat Group 1, red meat Group 2A. |
| Animal foods in general | Campbell (*The China Study*), Greger, Esselstyn: plant-predominant diets. The "Flexible" lens halves these adjustments. |
| Sweeteners | WHO (2023) advises against non-sugar sweeteners for weight control; IARC (2023) classified aspartame as Group 2B. Erythritol: Witkowski et al., *Nat Med* 2023. |
| Emulsifiers | Chassaing et al., *Nature* 2015 (CMC, P80 in mice); NutriNet-Santé cohort, *BMJ* 2023. |
| Colours | McCann et al., *Lancet* 2007 ("Southampton colours") → EU warning label. Titanium dioxide: no longer authorised in EU food (2022). Erythrosine: FDA revoked food use (2025). |

## The rules

Everything starts at **70** and adjusts per pillar:

1. **Processing (NOVA)** — group 1 **+20**, group 2 **+2**, group 3 **−6**, group 4 **−15**. If Open Food Facts has no NOVA group we estimate it from the ingredient list.
2. **Nutrients** (per 100 g, or per 100 ml for drinks; negatives capped at −35)
   - Sugar: up to −20 (food) / −22 (drinks). Extra −15 if more than half the product is sugar. Natural sugar in whole fruit / plain dairy is ignored unless sugar is an added ingredient.
   - Salt > 0.6 / 1.0 / 1.5 / 2.0 g: −3 / −7 / −11 / −15.
   - Saturated fat > 3 / 5 / 10 g: −4 / −8 / −12 (halved for whole plant foods such as nuts).
   - Industrial trans fat (partially hydrogenated oils): −20.
   - Fat > 17.5 g in a processed food: −4. Energy > 450 / 500 kcal in a processed food: −5 / −8.
   - Fibre ≥ 3 g: +4, ≥ 6 g: +8.
3. **Ingredients** (negatives floored at −14) — ≥ 80% fruit/veg/legumes/nuts +8 (≥ 40%: +4); whole grain first +4; legume first +4; sugar in the top three −5; refined syrups −4; refined flour −3; palm oil −3 / refined oil −2; flavourings −2; more than 15 ingredients −3; 1–3 ingredients +2; organic +2.
4. **Animal foods** (× 1.0 Plant-forward, × 0.5 Flexible) — processed meat −25; red meat −18; other meat/fish −12; dairy −12; eggs −10; small animal ingredients −3; plant-based +2.
5. **Additives** (capped at −30) — per additive: low −1, moderate −4, elevated −8, high −15 (reference list with sources in `AdditiveCatalog.swift`).

**Ceilings:** a "best avoided" additive caps at 49; processed meat caps at 35; ultra-processed (NOVA 4) caps at 69 — so it can never reach *Good*.

**Confidence:** *high* when sugar, salt, saturated fat and the ingredient list are all known. Low-confidence results show a "rough guide" note. Alternatives are only drawn from *high*-confidence products, so missing data never makes a product look healthier.

## Examples (live Open Food Facts data, September 2026)

| Product | Score |
|---|---|
| Rolled oats (single ingredient) | 100 Excellent |
| Whole-wheat biscuit cereal | 71 Good |
| Unsweetened organic soy drink | 61 Fair |
| Prepared lentils | 57 Fair (alternatives: plain Puy lentils 76) |
| Wholemeal sandwich bread | 55 Fair |
| Zero-sugar cola | 32 Limit |
| Classic cola | 18 Rarely |
| Cheddar slices | 11 Rarely |
| Hazelnut cocoa spread | 7 Rarely (alternatives: 100% peanut butter) |
| Bacon with nitrite | 1 Rarely |

Bump `Verdict.rubricVersion` whenever these rules change so cached AI prose is regenerated.
