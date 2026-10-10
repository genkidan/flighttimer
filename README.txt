FlightTimer Forever 2.0.4

2.0.4: Adds German localization by ExNex and English release documentation.

2.0.3: Separates learned timings by build, faction, locale, X/Y coordinates
and ordered stops. Keeps the Classic source visible throughout the countdown.
Handles explicit early-landing refusal. Interface remains 16001.

Flight timer with bundled Classic timings and learning for new Forever routes.

Features
- Detects flights selected at a flight master.
- Bundled Classic timings always take priority over older personal measurements.
- Records completed new routes with fully identified stops and averages
  subsequent measurements of that same path and client context.
- Preserves old personal measurements for inspection, but does not reuse them
  during flights because their faction, build and path cannot be verified.
- Shows remaining time, estimated arrival and a movable progress bar.
- Requests early landing on multi-hop routes. The next stop is an estimate;
  when its timing is unknown, the addon displays "next flight point".
- Early-landed flights are not learned because the actual arrival node is
  not confirmed. The original route is never overwritten by a shortened flight.
- Offers five selectable arrival sounds and an alert at 10 seconds.
- Restores flight tracking after /reload while still flying, with approximately
  one-second clock precision. Flights completed while tracking was unavailable
  are not learned.
- Supports French, English and German messages; other client languages use English.
- Thanks to ExNex for providing the German localization code on CurseForge.

Commands (both /ft and /flytimer)
test          Runs a 78-second demo without saving data; unavailable in flight.
lock/unlock   Locks or unlocks dragging.
reset         Restores the default window position.
show          Keeps the window visible between flights and after reload.
hide          Hides the idle window; flights still display automatically.
forever       Lists learned Forever routes (alias: newroutes).
foreverreset  Deletes learned Forever routes and their cached timings.
historyreset  Deletes all personal and Forever timings; preserves Classic data.

Sound button: left-click toggles sound, right-click opens sound selection.
SavedVariables: FlightTimerDB (shared between characters).
FlightData.lua credits the original Classic timing database sources.

Validation: run lua tests/regression.lua from the addon directory.
Client events, flight durations and actual landing behavior require in-game tests.
Classic identifiers still use the original X-only hashes. Their correspondence
and durations on Forever have not been certified. Existing Classic timings are
preserved; missing route-count or stop coordinates disable personal learning.
