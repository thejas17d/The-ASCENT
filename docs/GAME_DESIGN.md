# Game Design (summary)
Full creative brief: the "THE ASCENT — Master Game Development Prompt" (parts 1–20) given at project start.
Key pillars, in priority order:
1. **Lying rule boards** — every floor's rules are true / incomplete / false; clues always exist.
2. **Falling a floor** instead of dying on early floors; lethal from Floor 5.
3. **The Supervisor** — one recurring, learning, fair antagonist.
4. **Dread Meter** replaces health; high dread = unreliable perception.
5. **1998 Meridian Tower story** — Arjun, his father, the cover-up; letter + worker choices → 2 endings + hidden Floor 9.

Floors: G Reception · 1 Office · 2 Corridor · 3 Records · 4 Residence · 5 Hunt · 6 Inversion · 7 Collapse · 8 Roof.

## Floor 2 as built
- Corridor z 0→-44, 20 doors (201–221, no 213). Start lobby holds the notice board and chalk tally.
- Each pass: 55% chance of one anomaly from `data/anomalies/floor_02.json` (12 so far).
- Turn back if something changed, continue if not. 8 correct in a row → Room 213 opens (left side, where 214 was). Entering it clears the floor.
- Rules (`data/floor_rules/floor_02.json`):
  - "Walk. Do not run." — **incomplete**: punished only while knocking is audible.
  - "If you hear knocking, do not knock back." — **true**: interacting with the knocking door is a violation.
  - "Room 213 does not exist." — **false**: chalk clue "213 IS REAL" appears at tally ≥ 4.
- Violation / wrong call: tally wiped, dread up. Dread 100 = breakdown (prototype: reset; full game: drop a floor).
- The figure anomaly vanishes when you get within 9 m.
