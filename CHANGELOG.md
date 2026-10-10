# FlightTimer 2.0.4-Forever

- Add German localization (`deDE`). Thanks to ExNex for providing the German
  localization code on CurseForge.
- Provide both README files and the changelog in English.
- Update the addon version and startup messages to 2.0.4-Forever.

# FlightTimer 2.0.3-Forever

- New measurements distinguish build, faction, locale, X/Y coordinates and
  ordered stops; stop information is retained with each measurement.
- Tracking uses only personal measurements matching that exact context.
  Older data remains saved, but routes must be learned again.
- Routes with missing stop counts or coordinates are not learned.
  Elapsed-time tracking remains available.
- Tracking after a reload preserves the context of new flights; older saved
  flights without context do not produce new measurements.
- The Classic database label remains visible throughout the countdown,
  including when landing is imminent.
- An explicit `false` return from the early-landing API is treated as a
  refusal. A return without a value remains accepted for compatibility;
  it does not confirm an actual landing.
- Preserve all 808 Classic timings and their historical format. Official
  flight-point identities, map projections and actual Forever durations
  still require in-game validation.

Validation: tests/regression.lua and tests/audit_flight_data.lua with Fengari.
