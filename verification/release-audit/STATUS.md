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

## Further audit findings and fixes
- Production LiveActivityManager compiled against controllable ActivityKit doubles reproduced duplicate activities on overlapping starts. Added an operation revision so only the latest start can create, and Stop invalidates suspended starts. Both regression scenarios now pass.
- Latest Debug simulator build passes; actual row selection started bus 131 at Farrer Pk Stn Exit A.
- Lock Screen screenshots at 10:28 and 10:30 show current clock/countdown and native fill advance without reopening Catch. They also prove the bus marker stays behind: this remains a blocker, not a passed animation test.
- Expanded screenshot is explicitly an Xcode fixture preview, not a physical-device or live-ETA test. Header and times fit, with no street name.
- Removed seven orphan duplicate appiconset directories only after comparing every image byte-for-byte with its configured AlternateAppIcons copy. All configured icon artwork is retained.
