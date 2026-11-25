# Floor design (as built)

Every floor extends `FloorBase`, builds itself from the `Kit` (`scripts/world/kit.gd`), reads its rules from `data/floor_rules/floor_NN.json` and its notes from `data/notes/floor_NN.json`. Between floors you climb the **stairwell** (`scripts/floors/stairwell.gd`): a wall scrawl and a voice memory (`data/story/stairwell.json`) plus a checkpoint.

**Failure:** floors G–4 send you **down a floor**. That floor is marked *altered* and keeps its exit open if you already solved it. Floors 5–8 are **lethal**: you restart the floor from its last checkpoint. Breakdowns (Dread 100) follow the same rule.

| Floor | Rules (class) | Puzzle / goal | Threat | Failure |
|---|---|---|---|---|
| **G Reception** | lift (true) · sign register (true) · don't answer phone (incomplete) | Sign the register (your 1998 signature is already there) → booth opens → key cabinet code = frozen clock 3:33 → stair key | none (tutorial) | lift → reset G, altered |
| **1 Office** | desks empty (true) · 24 chairs (true) · if 25, leave (incomplete) | Return 6 personal items to the right worker lockers → ID cards (needed on 7). Mahadev's photo has no name — the **phone camera** shows it | 25th chair appears; step back out through the entrance within 40 s | stay with 25 → down to G |
| **2 Corridor** | walk (incomplete) · don't knock back (true) · 213 doesn't exist (false) | Anomaly loop, 8 in a row → Room 213 → stairwell | knocking, hallucinations | breakdown → down to 1 (wrong calls just reset the tally) |
| **3 Records** | keep lights on (true) · it reads unobserved (true) · don't let it finish (incomplete) | Collect 6 torn pages of the falsified inspection report; restore power at 3 fuse boxes (cooldowns) | It reads at aisle ends — **look at it** and it vanishes/relocates. Blackout → it **hunts** (lockers/desks, hold breath) | caught or it finishes → down to 2 |
| **4 Residence** | dinner at 8 (true) · don't open Papa's study (**false**) · don't make Mother try (true) | Photos + cassette → study code = birthday **1406** → Papa's letter: **keep / burn** (choice) → be seated before 8:00 | the faceless mother on her kitchen–table route | standing in front of her 1.5 s, or late for dinner → down to 3 |
| **5 Hunt** | hunts by light / hunts by sound / one is false (**randomised per playthrough**) | 3 fuses (each a checkpoint) → hoist panel → hoist | blind Supervisor with one true sense; **lures** (lamp flare / bucket clatter) show which; puddles + sheet metal are noise traps | death |
| **6 Inversion** | follow your shadow (incomplete) · your shadow is not yours (true) — board mirrored, phone reads it | Shadow repeats you 3 s late: hold plate pairs A (walk) and B (must run) → shadow turns hostile → lure it into the mirror room, pull the lever | your shadow (2.3 m/s) | death |
| **7 Collapse** | don't look at it (true) · don't look away from them (true) | Optional: free 6 frozen workers with their ID cards (spares lie here). Stairs open throughout | gaze on the overseer (1.6 s, warning tone); workers creep while unobserved | death |
| **8 Roof** | "YOU MAKE THE RULES NOW." | Chase across the roof (sections crumble) → climb the water tank (checkpoint; it can't climb) → catwalk to Papa → choice | Supervisor chase | death |

## Endings
- **ESCAPE:** always available. You wake in another building's lobby at 3:33; the loop continues.
- **TRUTH:** needs the letter **kept** (Floor 4) and **all six workers freed** (Floor 7). You read their names; you wake in the real world with the evidence.
- A run with **zero falls** unlocks Floor 9 (recorded in `user://unlocks.json`; the floor itself is Phase 6). New Game+ is flagged on any ending.

## Story beats (stairwell walls)
G→1 SITE OFFICE · 1→2 6 MEN. 6 NAMES. · 2→3 THE TALLY NEVER WIPES · 3→4 INSPECTION: PASSED · 4→5 IT HUNTS. · 5→6 NWOD SI PU · 6→7 14 JUNE 1998 03:33 · 7→8 THE ROOF IS NOT AN EXIT

## Known gaps (next passes)
- Art: walls/floors are kit-built boxes with PBR textures, dressed with 40 real CC0 models (desks, chairs, CRTs, sofa, brass puja items, site machinery…); every character is a rigged, mocap-animated Rocketbox avatar. Still primitive: doors, lockers, notice boards, the water tank, stairs.
- Floor 2's "altered" dimming only applies on the first pass after a fall.
- Floor 6's shadow passes through walls (it's a ghost); only the mirror room holds it.
- Floor 9, New Game+, Night Shift, Daily Corridor and Memories: see REPLAYABILITY.md.
