# Human Food backend (Supabase)

A single Edge Function plus three tables. It exists for two reasons:

1. **Your Gemini key never ships in the app.** Anyone can pull a key out of an app binary. Here it lives only as a server secret.
2. **Each product is sent to AI once, for everyone.** The first scan of a barcode generates the verdict. Every later scan, by any user, reads it from Postgres for free.

```
iPhone ──► Open Food Facts (product data, free)
   │
   └─► score computed on device (instant, free)
   │
   └─► POST /human-food/verdict ──► verdicts table hit? ──yes──► return cached
                                          │ no
                                          ▼
                              fetch product from OFF (server-side, trusted)
                              reserve 1 call from the daily budget
                              Gemini → safe-language filter → store → return
```

## Setup (about 10 minutes)

1. Create a project at [supabase.com](https://supabase.com) and install the CLI (`brew install supabase/tap/supabase`).
2. From this `backend/` folder:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push                                   # creates tables + functions
   supabase secrets set GEMINI_API_KEY=your-gemini-key
   # optional:
   supabase secrets set RATE_SALT=$(openssl rand -hex 16)
   supabase secrets set VERDICT_MODEL=gemini-3.5-flash-lite LABEL_MODEL=gemini-3.5-flash DAILY_AI_LIMIT=2000 \
     HOURLY_VERDICTS_PER_CLIENT=60 HOURLY_LABELS_PER_CLIENT=10
   supabase functions deploy human-food
   ```
3. In the iOS project, copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and set `HF_BACKEND_HOST` (e.g. `abcd.supabase.co`) and `HF_BACKEND_ANON_KEY` (Project Settings → API).

This is the same Gemini key you used in your other project. Paste it into `supabase secrets set`, never into the app.

## Endpoints

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/human-food/product?barcode=…` | — | `{ product }` added by the community, or 404 |
| POST | `/human-food/verdict` | `{ barcode, locale, rubricVersion, score: { value, tier, factors[] } }` | `{ verdict, cached }` |
| POST | `/human-food/label` | `{ images: [base64 jpeg ×1–3], barcode? }` | `{ product }` (also stored for everyone) |

`429` means the daily AI budget or the per-client hourly limit is used up. The app then falls back to its built-in local verdict, so users never see an error.

## Cost

Figures are estimates from public pricing as of September 2026; check [Gemini pricing](https://ai.google.dev/pricing) before you rely on them.

- Verdict: about 1.5k input + 350 output tokens. With `gemini-3.5-flash-lite` (≈ $0.30 / $2.50 per 1M tokens) that's **≈ $0.0013 per product**, so ≈ **$130 per 100,000 distinct products**, once. With `gemini-3.5-flash` (≈ $1.50 / $9.00) it's ≈ $0.005 per product.
- Label read (vision, for products missing from every database): ≈ $0.01 each with Flash.
- A "Pro" model isn't needed. The score is already computed, and the model only writes short, constrained prose.
- Cost grows with **distinct products**, not users or scans. Popular items are paid for once.
- `DAILY_AI_LIMIT` is a hard ceiling per day, whatever happens.

## Notes

- Verdicts are keyed by `(barcode, rubric_version, language)`. Bump `Verdict.rubricVersion` in the app when the scoring rules change.
- Product facts for the prompt come from Open Food Facts or the `products` table, never from the client. Only the already-computed score is sent by the app, and it's clamped and trimmed.
- Community label reads are stored first-write-wins. Add moderation (e.g. require two matching reads) before scaling.
- Security details (rate limits, cache-poisoning protection, prompt-injection guard) are in [docs/SECURITY.md](../docs/SECURITY.md).
