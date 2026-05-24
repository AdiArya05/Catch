# Catch Transit Research Roadmap

## Product Thesis

Catch should not compete by showing the most transport data. It should compete by reducing decision time.

The best transit apps answer "what should I do now?" before asking the user to browse timetables. For Catch, that means the first screen should quickly resolve:

- Which place am I leaving from?
- Which stop should I use?
- Which bus matters?
- Can I catch it?
- Should I leave now?

The strongest differentiator is not an open-ended AI chatbot. It is narrow, embedded assistance: rankings, reminders, confidence labels, routine shortcuts, crowding clarity, and plain-language microcopy.

## Benchmark Patterns

### Nearby First

Transit, Apple Maps, Google Maps, and Citybus all make nearby departures available immediately. Catch should never feel like it opens to a blank search tool.

Implementation direction:
- Keep nearby stops visible on the home screen.
- Put the best nearby decision above the raw nearby list.
- Use location and saved places to choose a default context automatically.

### Routine Over Query

Citymapper, Moovit, Google Maps, Transit, and Apple Maps all assume most trips are repeated. Catch should treat Home, Work, School, Gym, and custom places as first-class objects.

Implementation direction:
- Saved places should have a usual stop.
- Saved places should have a walk time.
- Home and Work should become one-tap actions.
- The app should remember useful recent routes.

### State Into Action

The best apps convert uncertainty into instruction: leave now, transfer here, get off soon, take this stop, avoid this route.

Implementation direction:
- Convert ETA + walk time into catchability badges.
- Convert load codes into human labels.
- Convert monitored/scheduled data into confidence labels.
- Recommend a backup stop when the usual option is weak.

### Decision Microcopy

Useful labels beat transit jargon.

Good labels:
- Best stop right now
- Can I catch it?
- Leave now
- Too tight
- Next one safer
- Seats likely
- Standing room
- Packed
- Live
- Scheduled only
- Get me home
- Back the same way?

Avoid raw or agency-first language when a decision label is possible.

### Functional Motion

Motion should clarify state or place, not decorate the board.

Good uses:
- Active bus progress
- Leave-now alert state
- Alight reminder progress
- Pull-to-refresh
- Live status transitions

## Catch Feature Blueprint

### Must Build

1. Smart Home Brief

Purpose: Give one useful sentence immediately on app open.

Example:
`Good evening. Best way home: 154 from Blk 206A in 6 min.`

Implementation:
- Add a hero card above saved places / nearby stops.
- Generate with deterministic heuristics first.
- Use AI only as optional phrasing if needed.

2. Best Stop Right Now

Purpose: Compare nearby usable stops and recommend one.

Example:
`Best stop right now`
`Shortest walk + safest arrival window.`

Implementation:
- Score nearby stops by walking distance and next useful arrivals.
- Prefer stops with at least one bus that is catchable after walk time.
- Surface one recommendation before the nearby list.

3. Can I Catch It?

Purpose: Turn raw ETA into an action.

Badge rules:
- `Easy`: bus arrival - walk time > 5 min
- `Leave now`: 0...5 min buffer
- `Too tight`: arrival is sooner than walk time

Implementation:
- Add badges to bus rows and smart cards.
- Add secondary copy like `Next one safer` when the first bus is missed but NextBus2 is good.

4. Walk-To-Stop Timing

Purpose: Make ETA realistic.

Implementation:
- Saved locations already store `walkMinutes`.
- Nearby stops can estimate walking time from distance.
- Display small walking badges like `3 min walk`.

5. Preferred Stop Per Saved Place

Purpose: Make Home, Work, School, Gym useful instead of decorative.

Current state:
- Catch already has `SavedLocation.busStopCode`, `busStopDescription`, and `walkMinutes`.

Next step:
- Mark usual stops visually with a `Usual stop` chip.
- Allow editing walk time from saved places.

6. Leave Now Alerts

Purpose: Move from passive checking to active assistance.

Current state:
- Catch already has leave-now alert logic.

Next step:
- Expose it directly from bus rows / best stop cards.
- Make notification copy deterministic fallback first:
  `Leave now to catch 154 from Blk 206A.`

### Should Build

7. Crowding Labels

Map LTA load codes:
- `SEA` -> Seats likely
- `SDA` -> Standing room
- `LSD` -> Packed

8. One-Tap Get Me Home / Work

Implementation:
- Quick-action pills under the smart brief.
- Tap opens the saved place's usual stop or best route card.

9. Live / Delayed / Scheduled Confidence Badge

Map `Monitored`:
- `1` -> Live
- `0` -> Scheduled only

Delay detection can come later by comparing scheduled vs ETA drift if available.

10. Smart Suggestion Ribbon

Cards:
- Best way home
- Favourite stop
- Nearest stop
- Recent route

11. Latest Route Back

Purpose: Save effort for return trips.

Implementation:
- Store last selected stop/service/time.
- Show `Back the same way?` if recent enough.

12. Direction and Sort Controls

Controls:
- Soonest
- Service no.

### Could Build

13. Backup Stop During Disruption

Purpose:
Suggest another stop when the usual service is weak, delayed, or too tight.

14. Lite Alight Reminder

Purpose:
Trip companion value without full route planning.

15. Unified Search

Placeholder:
`Bus no., stop, block or landmark`

Search intents:
- Bus number
- Stop code
- Stop name
- Road name
- Saved place
- Landmark aliases

16. Mini Bus Progress

Purpose:
Humanize bus movement.

Examples:
- `3 stops away`
- `850m away`

This is higher complexity because LTA arrival data alone may not expose enough vehicle position context.

## Recommended Home Screen Hierarchy

1. Place pills
2. Smart Home Brief
3. Quick actions
4. Best Stop Right Now
5. Usual Stop Card
6. Nearby stop list

The screen should behave like a decision surface, not a timetable directory.

## Build Sequence

### Layer 1: Decision Clarity

- Smart Home Brief
- Preferred Stop per Place polish
- Walk-to-stop timing
- Can I Catch It badges
- Best Stop Right Now
- Live / Scheduled badges

### Layer 2: Routine Assistance

- Leave Now alert UI
- Get Me Home / Work actions
- Crowding labels
- Smart Suggestion Ribbon
- Latest Route Back
- Sort controls

### Layer 3: Trip Companion

- Backup stop suggestions
- Lite alight reminder
- Unified search
- Mini bus progress

## What To Skip For Now

- Full multimodal journey planning
- Ticketing
- AR wayfinding
- Open-ended AI chatbot
- Heavy social/crowdsourcing features

Catch should stay bus-first, fast, and routine-driven.

