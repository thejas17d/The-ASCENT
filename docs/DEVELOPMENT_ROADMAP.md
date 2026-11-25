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
## Phase 4 — The Supervisor (NEXT)
 (NavigationAgent3D state machine)
## Phase 5 — Floors G,1,3–8 · Phase 6 — story/endings/Floor 9
## Phase 7 — touch controls, gyro, haptics, Android export · Phase 8 — QA
