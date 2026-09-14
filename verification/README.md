# Catch verification — 12 September 2026

Current screenshots are from the actual Debug Catch app on iPhone 17 Pro simulator, using live LTA responses and a simulated Singapore location.

Verified in the running app:
- Home search, refresh, add, and profile header; Home / Maps / Settings navigation.
- Maps loads bus stops, opens a stop sheet with three arrival slots per service, opens stops from search, and recentres using the location button.
- Visible bus pin button enables Live Board; starting it changes the control to Stop Live Board.
- Compact Live Activity displays only service number left and a working minutes-only countdown right.
- Lock Screen displays the system current time left, exact predicted arrival time right, white bus marker at the fill endpoint, and one tracked service.
- Debug Pro testing switch stays enabled after app restart and StoreKit refresh.
- Debug and Release builds passed; git diff --check passed. No crash occurred in these tested flows.

Screenshots: home-maps-update.png, maps-arrivals.png, pro-testing.png, compact-live-activity.png, live-activity-current-arrival.png.

The Debug Pro switch is excluded from Release. The simulator is left on the updated Debug build with Pro enabled.

Live Activity limitations: the native clock/countdown advance while the app is suspended. Custom marker/fill and colours update together when ActivityKit receives new content; iOS controls animation scheduling. Predictions expire after at most 90 seconds (or 30 seconds after arrival), at which point the board requests an update and hides the old arrival clock. This project does not have server push infrastructure for continuous background LTA updates. Physical-device and long-running background verification remain outstanding.

Earlier live-board-states.png is a separate native fixture preview, not the final app or live LTA data. Earlier isolated assertions covered pin ordering/persistence and catchability selection. Existing app icon and unused StoreKit-result warnings remain.

## Later refinements

- Expanded Dynamic Island shares the Lock Screen arrival card without its footer. Compact presentation remains bus number + minutes.
- Maps opens/recentres at a 420-metre region around the reported user location. Visually checked on simulator.
- Home header uses the existing 24-point content margins and equal 44-point control heights. The greeting, saved places, nearby list, and catchability styling remain as before the Maps work.
- Pin controls now belong to the bus number group, separated from catchability status. Restored the previous timing-strip corner radius.
- A scene-active task refreshes the tracked bus at each minute boundary across all tabs and stops when the scene leaves active. This is not a workaround for suspended background updates.
- Assertions using the actual progress calculation passed for each of eleven minute positions from 0% through 100%, while preserving the predicted arrival timestamp.
- New screenshots: home-refined.png and maps-street-level.png.

## Map search and tracking refinements

- Stop selection preserves the map region span instead of resetting to 1600 metres; camera pans to put the selected stop above the sheet.
- Map search is a medium/large popup containing one focused text field and inline stop results. Tested entering Tekka and selecting Tekka Ctr.
- Bus pinning is a labelled footer action outside the arrival/status row. Shared Live Board control is available in map stop sheets.
- Live Activity service badge is now 22-point bold at the leading edge, shared with expanded Dynamic Island.
- Settings background matches Home (292929 dark / F5F5F5 light).
- Profile stores tracked Live Board sessions independently from inferred completed-trip receipts. Tested starting bus 23 at Tekka Ctr and seeing its timestamped Profile entry. Pending-session migration avoids duplicate history entries. Existing completed logs are no longer pruned after fourteen days; previously deleted history cannot be recovered.
- Screenshots: map-search-popup.png and profile-tracked-buses.png. Debug and Release builds passed, with no whitespace errors.

## Restore original card and simplify controls

- Restored catchItCard from repository HEAD, removing the extra stop chips and returning to the original single-card tap behaviour. Checked Home visually.
- Centered the search icon/text group in its capsule.
- Removed bus pin footer; original swipe reveal and context menu remain, with a compact pinned indicator.
- Added persisted Use first bus when none is pinned setting (default on). First explicit pin still takes precedence. Verified bus 141 Live Board starts at unpinned stop 50259.
- Removed the Settings page heading. Verified fallback and Debug Pro switches are enabled.
- Map search now uses a solid animated overlay rather than modal material presentation. Verified focused input and a clear map behind the popup.
- Expanded Dynamic Island uses the shared card with zero added content margins. iOS still owns the camera clearance and outer island geometry; exact expanded island geometry has not been visually verified in this pass.
- Debug/Release builds and whitespace checks passed. New screenshots: home-restored.png, map-search-overlay.png.

## Single map search and navigation fixes

- Removed bottom map search panel completely. Top editable search filters map annotations; matched names stay visible, empty searches report no matches. Verified Tekka query shows its map pin with no second search UI.
- Removed swipe-reveal pin wrapper. A compact per-bus menu exposes Pin/Unpin; verified menu presentation.
- Removed additional Debug/fallback controls from Settings presentation; existing stored values and Pro test entitlement remain effective.
- Added a forwarding native tab-selection observer so Home selection/reselection resets the Home stop detail and dismisses map stop sheets. Simulator coordinate actions failed, so actual Home re-tap remains unverified.
- Expanded Dynamic Island now places bus number and stop in top regions, leaving time/bar/status below; avoids stacking a full header beneath reserved camera space. Expanded Island screenshot validation remains outstanding.
- Debug and Release build passed; git diff --check passed. Latest Debug build installed.

## Arrival progress correction and Profile cleanup

- Removed the Tracked buses section from Profile; confirmed the receipt is again the first card in the running app. Existing stored history was not erased.
- Approach progress now uses a minimum fifteen-minute arrival window, rather than starting at zero whenever Live Board opens. A two-minute prediction starts at approximately 87%.
- A single Animatable progress value drives both the fill width and white marker position, with a 0.8-second transition and Reduce Motion support.
- Regression assertions passed for initial positioning and monotonic 15-second progress steps for 0/1/2/5/15/25 minute predictions, including completion clamping.
- Debug and Release builds passed. Animation appearance on an actual content update still needs physical-device verification; custom movement remains dependent on ActivityKit updates, not continuous background execution.

## Per-bus Live Board and map-sheet interactions

- Two compact, accessible bus-row actions: Pin/Unpin and Start/Stop Live Board. Removed the stop-wide Live Board banner.
- Explicit Live Board service selection is independent of pinned ordering. Active service remains selected across unpinning, missing predictions, and refresh. Old in-flight stop refreshes cannot overwrite a newer active activity.
- Tests using the actual service resolver passed explicit-vs-pinned priority, unpinning, missing prediction placeholder, and stop isolation.
- Simulator verified saving/unpinning a map stop, starting bus 131 directly from its row, unpinning it while keeping Live Board running, restoring the pin, and expanding the sheet with the grabber. Full-area upward swipe uses the native resizes interaction plus a directional expansion gesture; physical touch validation remains for the user.
- Added haptics for tab selection and header actions; existing bus pin/start and map save/recenter feedback remains. Physical haptic feel cannot be tested in simulator.
- Bus badge uses a smaller bold size and softer background in Live Activity and Dynamic Island. Physical-device layout/motion validation remains outstanding.
- Debug Pro access defaults on for fresh testing installs and retains the phone's existing enabled testing preference. Release entitlement checks remain StoreKit-based.
- Per-user request, no install or launch was performed on the physical phone in this pass; only builds and simulator actions.
- Screenshot: per-bus-controls.png.

## September 13 — Live Board selection and navigation refinement
- Restored the stop-level explanatory Live Board control. Simulator verified that it starts the first displayed service (21 at stop 07211), and choosing the second row switches the active service to exactly 23. Stop control also verified.
- Restored the rounded blue Live Board symbol/background for individual service controls.
- Home header now contains Search, Refresh, and Profile. Bottom navigation groups Home/Maps/Settings on the left, with an independent Add control on the right. Removed the native duplicate tab bar after visual verification. Add opens the existing location flow; reselecting Home dismisses stop details.
- Saved location chips support hold-and-drag reordering using the existing persisted sort order. Physical dragging was not verified because simulator coordinate gestures are unavailable through the current UI automation surface.
- Expanded Island stop name uses smaller, leading-aligned two-line text in the trailing region. Actual expanded Island rendering on a phone remains to be checked.
- Signed Debug and Release generic iPhone builds and Debug simulator build passed. No phone install or launch was performed. Debug retains Pro testing access.
- Selected-service and arrival-progress regression checks passed; git diff --check clean.
- Screenshots: home-navigation.png and live-board-selection.png.
- Custom progress drawing animates between ActivityKit content updates. Without push updates, continuous custom progress animation while the app is suspended is not guaranteed by the current implementation.

## September 13 — restore native navigation, feedback foundation
- Undid the last custom left-group/right-plus navigation, restored native Home/Maps/Settings tabs and the header Add button. Kept the profile icon and saved-stop reorder gestures. Removed the last top-level explanatory Live Board card and restored the earlier per-row livephoto/stop symbols. Removed the latest forced trailing Island width/alignment.
- Simulator visually verified restored Home and opened Settings by deep link, then Feedback Board through its actual button. Verified missing-backend error and composer. Native tab tapping and drag gestures remain unverified through this automation surface.
- Live Board retains its labelled estimate until the predicted arrival plus 30 seconds instead of blanking after 90 seconds. No background APNs service exists; this does not create fresh predictions while suspended.
- Added feedback board/composer, secure anonymous-session REST client, SQL migration with RLS, owner-only pending posts, moderated public posts, developer responses, per-author rate limits and idempotent submissions. No fake seed posts or local success fallback.
- Backend remains UNDEPLOYED and end-to-end delivery UNVERIFIED pending project URL/publishable key, anonymous auth enablement and migration. See backend/README.md. No email sent.

## September 13 — numbered map clusters and matching Live Board controls
- Replaced viewport sampling/discarding with world-anchored counted clusters at wider zooms. Cluster taps fit their member bounds, and street zoom shows individual stops. Removed the redundant zoom-in warning.
- Regression check extracted the actual grouping method: 1,000 stops counted exactly once, stable membership on small pans, selected stop excluded from cluster count and kept visible, street zoom restores individual markers. Passed.
- Restored the long stop-level Live Board bar inside the scroll content and matching rounded tinted per-service icons. Added smooth press/symbol transitions with reduced-motion handling for scale/color transitions.
- Simulator verified top button starts first service 21 and second-row control switches exactly to 23. Reviewed actual rendered button layout. Physical map pinch/cluster tap gestures remain unverified.
- Debug simulator and signed Debug iPhone builds passed; git diff --check clean. No physical phone installation.

## Original Live Board pill restored
Restored the original git-version label styling: black-weight text, circular icon backing, red active/blue inactive foreground and translucent capsule, no subtitle or chevron. Count reflects the current single-bus tracking behavior. Simulator verified top start selects 21, row selection switches to 23, and top stop ends 23. Simulator build and diff whitespace check passed.

## Saved-place reordering and truthful receipt totals
- Home chips use an explicit hold-then-drag gesture instead of competing context-menu and drag/drop recognizers. Spring animation moves adjacent chips; persistence occurs at gesture end, avoiding repeated database writes during movement. Accessibility move actions are available too.
- Settings Saved Places has explicit Reorder/Done state. Custom swipe recognizers are disabled during native reorder mode.
- Simulator tested moving a temporary Work place before College through the accessibility move action, then relaunched and verified the order persisted. Removed the temporary Work place afterward. Physical long-press drag animation still needs phone verification.
- Removed fixed fuel/CO2/taxi savings multipliers. Receipt aggregates source-tagged detected trips; most-used place comes from those trips, not saved-place order. Legacy records remain stored but excluded because provenance is unknown. Trip history shows contributing bus/stop/date entries; detection is explicitly an estimate, not boarding confirmation.
- Detection now requires accurate recent location near the stop before an arrival/departure can count. Regression tests passed for remote start, inaccurate/stale location, single completion, and departure without an arrival. Source tagging migration launched successfully with existing simulator data. Profile showed zero detections and preserved three legacy records.
- Debug simulator and signed Debug iPhone builds passed. Feedback backend remains unconfigured. User needs help creating Supabase; in-app dashboard sign-in redirected to an unavailable GitHub verification page. Awaiting user sign-in through their normal browser before continuing hosted setup.

## Autonomous timer progress and motion pass
- Switched the live bar fill to native ProgressView(timerInterval:countsDown:false), retaining the minute-only system timer. Simulator Lock Screen screenshots at 16:37 and 16:38 showed the fill advance and countdown change while Catch was inactive. The bus marker/colour still reflect the last ActivityKit update; revised predictions require the unconfigured push service.
- Top Live Board pill animates its state and symbol changes, sharing the existing press style. Edge back-swipe follows finger translation directly rather than an animated 92pt cap. Reordering offsets the held chip under the finger, elevates it above neighbours and disables strip scrolling during the drag; neighbouring items animate their layout. Physical drag feel still requires phone feedback.
- Debug simulator and signed iPhone builds passed, receipt regression passed, diff whitespace check passed. Installed the latest signed Debug app on the paired iPhone. Foreground launch was denied because the device was locked; a Catch process was present, but a successful foreground launch was not verified. Requested unlock.
- Supabase dashboard opened in Arc but remained blank. Requested user sign-in. No backend has been created or connected, and no APNs credentials have been provided. See backend/README.md for separate feedback and background-update requirements.

## 13 September — refresh layout and pre-release checks

- Home retains the existing catchability result while refreshing the same stop, eliminating the deliberate collapse to a loading row. Switching stops still clears the old stop's results; failed refreshes explicitly clear stale results.
- Stop arrival failures now show an explicit retry action rather than implying there are no buses. Cancelled requests do not apply results after leaving the view.
- Signed Debug build and simulator build passed for the Home change; signed Debug build passed after retry handling. Receipt regression and diff whitespace checks passed.
- Simulator confirmed live arrivals for Farrer Pk Stn Exit A, top-button start for 131, explicit switch to 141, stop, and return Home. Accessibility reorder moved Work earlier and restored it later. This does not verify physical hold-and-drag smoothness.
- Supabase new-project form prepared with Catch / Asia-Pacific. Database password entry and project creation require user handoff; backend connection and end-to-end feedback verification remain outstanding. No App Store submission performed.
