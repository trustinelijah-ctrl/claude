# Security notes

What protects Human Food, and what to check before launch.

## Secrets

- **The Gemini key lives only on the server** (`supabase secrets set GEMINI_API_KEY=…`). The app never needs it.
- `HF_GEMINI_DEV_KEY` is for DEBUG prototyping only. The Swift code ignores it in Release, and `Config/HumanFood.xcconfig` blanks it for the Release configuration, because Info.plist variables are otherwise substituted into every build.
- `Config/Secrets.xcconfig` is git-ignored. The Supabase **anon** key in the app is public by design. It grants nothing, because every table has row-level security with no policies, and the SQL functions are revoked from `anon`.

## Backend abuse

| Risk | Mitigation |
|---|---|
| Someone scripts the API to burn your Gemini budget | Per-client hourly limit (salted hash of the IP, the raw IP is never stored): `HOURLY_VERDICTS_PER_CLIENT` (60) and `HOURLY_LABELS_PER_CLIENT` (10). Plus a global `DAILY_AI_LIMIT` hard cap. Cached reads are free and unlimited. |
| Tampered score poisons the shared verdict cache | Verdicts are keyed by `sha256(score payload)`. A fake score creates its own entry that honest clients never request. |
| Fake "community" product shadows a real one | Product facts come from Open Food Facts first. Label reads are refused for barcodes OFF already knows, and they're first-write-wins. |
| Prompt injection through crowd-sourced product text | Product data is wrapped in `<product_data>` and the model is told to treat it as data only. Output is length-capped and passes the safe-language and brand filter before it's stored. |
| OFF outage or slow response | 8 s timeout. An HTML error page is treated as "not found", not a crash. |

## Privacy

- `PrivacyInfo.xcprivacy` declares no tracking, UserDefaults use (reason CA92.1), and label photos sent for app functionality.
- Label photos go to Gemini to be read and are **not stored**. Only the extracted text is kept.
- History, allergies and preferences stay on the device.

## Before launch

- Set `RATE_SALT` to a random secret (`supabase secrets set RATE_SALT=$(openssl rand -hex 16)`).
- Consider Apple **App Attest** (DeviceCheck) so only your genuine app can call the backend. That's the strongest defence against scripted abuse.
- Add moderation for community label reads (for example, require two matching reads) before relying on them.
