# Safe language: how Human Food avoids trouble with brands

> This is product design guidance, not legal advice. Before launch, have a lawyer in your main market review the copy, the disclaimer and the store listing.

Food scanners do get sued. Yuka, for example, was taken to court by French processed-meat producers in 2021 over how it presented nitrites. Claims like that usually turn on **false or unfounded statements of fact** that harm a **specific company's** product. So Human Food is built to talk about **food**, not **companies**, and to state **opinions based on disclosed data**.

## The rules the app follows

1. **Transparent, deterministic method.** Every score comes from published rules (`docs/SCORING.md`) applied the same way to every product. No hand-picked targets, no AI-invented scores.
2. **Opinion framing.** Everything is "our rating", "in our view" or "research suggests". The disclaimer is shown on every result, in Settings and in onboarding.
3. **Facts are attributed.** Additive notes cite what a named body said ("IARC classifies…", "no longer authorised in the EU…"). They never say an additive *is* harmful.
4. **No brand names in generated text.** The AI prompt forbids naming brands, and `SafeLanguage.clean` (Swift) / `clean()` (backend) replaces the product's brand with "this product" anyway.
5. **Banned words.** *toxic, poison, dangerous, harmful, unhealthy, junk, fake, carcinogenic, causes cancer, deadly, kills, garbage…* are rewritten automatically on both the server and the device.
6. **Gentle tier labels.** "Rarely · Worth swapping when you can" — not "Bad" or "Avoid".
7. **Generic alternatives.** AI ideas are food types ("Rolled oats with berries"). Product alternatives are other real products ranked by the same score, and they are labelled only with their score.
8. **Data provenance.** Product data is attributed to Open Food Facts (ODbL) on every result. Community label reads are labelled as such.
9. **No logos or trademarks** in the app's own design or marketing. Product photos come from Open Food Facts contributors.

## Before launch

- Add a "Report a problem" flow so manufacturers and users can flag wrong data. Fixing errors quickly is your best defence.
- Keep a changelog of rubric versions (`Verdict.rubricVersion`).
- Don't make medical claims in the App Store listing ("prevents cancer", "detox" and so on).
