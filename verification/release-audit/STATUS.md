# Release audit — 15 September 2026

Release readiness is NOT established. Earlier verification/README.md entries are historical, not proof of current behavior.

## Verified this audit
- Commit 83f6e25: compact Dynamic Island renders a small bus.fill symbol and abbreviated minutes, with constrained widths, in the running iPhone 17 Pro simulator.
- Debug simulator build and signed generic-device Release archive succeeded. Existing alternate-app-icon warnings remain.
- Receipt harness passed remote-start, inaccurate/stale location, arrival/departure, and duplicate completion cases. The two detection method bodies were compared against current AppState source and match (whitespace ignored). Persistent-log deduplication remains separate coverage.
- Configured Supabase endpoint is reachable; anonymous auth enabled.
- Live backend test: two anonymous sessions; one clearly labelled unpublished report (fc2efb18-c5d2-4b04-96b3-771cf376440d). Successful submission and idempotent retry; author sees one received report; second author sees none; client status mutation, author-ID read, short submission, and unauthenticated submission rejected. No real user reports altered.

## Release blockers / remaining verification
- Activity.request uses pushType:nil. Fresh ETAs only fetch in active scene. APNs registration/worker is absent. Need server-only Apple APNs signing key, key ID and configured worker before background refresh can pass.
- Native ProgressView advances from dates, but TimelineView bus marker remains stale when suspended. Current code does not satisfy synchronized movement.
- Expanded Island and Lock Screen need fresh runtime screenshots and elapsed-time comparisons after resolving marker updates.
- Pin/stop long-hold reorder: actual gesture, cancellation, persistence and scrolling conflicts need runtime verification.
- Navigation, maps clustering/search/sheets, feedback composer retry/error handling, StoreKit Release entitlements/purchases/restoration, profile persistence, notification controls, and accessibility remain to be stress-tested.
- Feedback publication visibility and hourly rate-limit concurrency not yet tested against deployed backend.
- Review current legal URLs, privacy disclosures, release metadata, icons, and signing before upload.

No App Store upload or submission performed.
