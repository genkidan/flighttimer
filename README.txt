FlightTimer Forever 2.0.2

2.0.2: Corrects the TOC interface to 16001 for the WoW Forever 1.60.1 client.

Flight timer with bundled Classic timings and learning for new Forever routes.

Features
- Detects flights selected at a flight master.
- Bundled Classic timings always take priority over older personal measurements.
- Records completed new routes and averages subsequent measurements.
- Shows remaining time, estimated arrival and a movable progress bar.
- Requests early landing on multi-hop routes. The next stop is an estimate;
  when its timing is unknown, the addon displays "next flight point".
- Early-landed flights are not learned because the actual arrival node is
  not confirmed. The original route is never overwritten by a shortened flight.
- Offers five selectable arrival sounds and an alert at 10 seconds.
- Restores flight tracking after /reload while still flying, with approximately
  one-second clock precision. Flights completed while tracking was unavailable
  are not learned.
- Supports French and English messages.

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
