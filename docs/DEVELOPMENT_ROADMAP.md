# Roadmap / session checklist
## Phase 1 — audit & plan ✅
- [x] No prior project existed → new Godot 4.4.1 project at Desktop/Dev/TheAscent
- [x] Godot installed at `~/.godot/` (portable)

## Phase 2 — Floor 2 prototype ✅ (playable, greybox)
- [x] FP controller, flashlight, interact
- [x] Procedural corridor, 20 doors, props, lights
- [x] Rule board (true / incomplete / false rules) + violations
- [x] Anomaly loop, 12 anomalies, 8-streak, chalk tally
- [x] Room 213 reveal + clue, floor clear
- [x] Dread (darkness, anomalies, mistakes) + breakdown
- [x] Procedural placeholder audio
- [ ] **Needs human playtest for fun/tuning** (anomaly subtlety, 55% rate, dread rates)

## Phase 3 — core systems ✅ (tested headless; needs playtest)
- [x] Autoloads `GameState` (save/load, inventory, choices, settings, input map) + `Dread`
- [x] `FloorBase` class — every floor extends it; Floor 2 rebuilt on it
- [x] Main menu (Continue / New Game / Quit)
- [x] Flashlight battery drain + spare batteries [R], low-battery flicker
- [x] Chalk marks [C], diyas [G] (40 s safe glow), phone camera [Q] reveals render layer 2
- [x] Inventory panel [Tab]; random pickups in the corridor
- [x] Hiding (start-lobby cupboard) + hold breath [Space] → gasp when empty; `player.noise` exposed for AI
- [x] Checkpoint autosave after every judgement (user://save.json)
- [x] Event Director: 7 data-driven events, dread gating, cooldowns, quiet/relief rhythm, 2 fair "fake" events
- [ ] Floor-down penalty is recorded (`GameState.falls`) but can't move floors until Floor 1 exists
- [ ] Settings screen (values exist in GameState.settings, no UI yet)
## Audit + UHD pass ✅ (2026-11-25)
- [x] Independent code review: 13 defects found, all fixed, each with a regression test
- [x] CC0 PBR textures (Poly Haven), detailed corridor kit; Forward+ on desktop, Mobile renderer on phones
- [x] Quality presets Low/Medium/High/Ultra (Ultra = native resolution, UHD on a 4K display, MSAA 4x + TAA, SSR, 8K shadow atlas)
- [x] Volumetric fog, SSAO, SSIL, glow, AgX tonemap; film grain / vignette / chromatic aberration / VHS tear post FX
- [x] Torch beam pattern, dust motes, decals, fluorescent fixtures, cinematic title screen
- [x] Audio buses + reverb, surface footsteps, heartbeat, subtitles for every sound event
- [x] Pause menu, settings screen (user://settings.json), F11 fullscreen, crouch
- [x] Readable notes (collectibles) that clue the lying/incomplete rules

## Phase 4 — The Supervisor ✅ (dev test level; needs playtest)
- [x] State machine, senses (sight/sound/light, per-floor toggles), awareness, amber notice beat
- [x] Navmesh baked at runtime; patrol / investigate / search / chase / attack / return
- [x] Hiding-spot learning, fair spawns, readable lamp states, heavy footsteps
- [x] Archive test level with lockers + desks (title menu → Test: The Supervisor)
- [x] 23 AI tests
- [ ] Rigged/animated character model (art)

## Phase 5 — Floors ✅ (all playable end to end; needs human playtest)
- [x] Kit (`scripts/world/kit.gd`): rooms with openings, walls, lamps, boards, doors, lockers/desks (hide spots), items, notes, triggers
- [x] Progression: stairwell interludes (story beat + voice memory + checkpoint), floor-down penalty with altered floors, death on 5–8, solved floors stay open
- [x] HUD keypad + choice dialogs; carry-one-item; per-floor rules/notes data
- [x] G Reception · 1 Office · 2 Corridor (integrated) · 3 Records · 4 Residence · 5 Hunt · 6 Inversion · 7 Collapse · 8 Roof
- [x] Two endings (ESCAPE / TRUTH), Floor 9 unlock flag, New Game+ flag
- [x] `tests/test_floors.gd` (85 checks) plays every floor's puzzle and every rule's consequence
- [ ] Art pass per floor (props, characters), more anomalies on altered floors
See `docs/FLOOR_DESIGN.md`.

## Phase 6 — replayability + story systems ✅
- [x] Night Shift (darker, faster, a lie on every board revealed by the phone) + New Game+ bonuses and loop count
- [x] Memories journal across runs (29 entries), voice notes that calm Dread (V)
- [x] Daily Corridor (date-seeded, local best, leaderboard integration point)
- [x] Hidden Floor 9 — The Blueprint (Supervisor's identity, sequel hook)
- [x] Residence art pass (clutter), endings polish (loop count, credits)
- [x] `tests/test_phase6.gd` — 31 checks
See `docs/REPLAYABILITY.md`.

## Phase 7 — Mobile (NEXT): touch controls, gyro, haptics, Android export
## Phase 7 — touch controls, gyro, haptics, Android export
## Phase 8 — QA and release checklist
