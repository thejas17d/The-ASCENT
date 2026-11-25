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
- [x] Procedural placeholder audio (replaced by recordings in Phase 9; synth kept as fallback)
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

## Phase 7 — Mobile ✅ (APK builds; not yet run on a real phone)
- [x] Touch controls: floating joystick (edge = run), drag-to-look, multi-touch buttons on the real input actions, crouch toggle, contextual HOLD BREATH
- [x] Gyroscope look (optional; axes unverified on hardware), vibration on key moments, Mobile settings section
- [x] UI scales with resolution (canvas_items) — phones and 4K
- [x] 1K texture set for phones / Low preset; Mobile renderer verified on desktop
- [x] Android export: preset, templates, SDK/JDK/keystore wiring, app icon; `build_android.cmd` builds + installs (APK ≈ 86 MB)
- [x] `.import` files are now committed (texture compression settings were being lost)
- [x] `tests/test_mobile.gd` — 28 checks
- [ ] Run on a real phone: 60 fps target, gyro axes, haptics, button reach
See `docs/MOBILE_BUILD.md`.

## Phase 8 — QA & release readiness ✅ (v0.8.0)
- [x] Second independent code review: 13 defects, all fixed + regression tests (Floor 9 breakdown, stuck touch joystick, Floor 1 carry after Continue, Floor 5 spawn distance, dialog mouse capture, Memories loss, mother during dialogs, Daily violations, tank re-climb, blanked messages, photo memories, Ramesh in a column, respawning cassettes)
- [x] End-to-end playthrough with real scene changes (title → G…8 → TRUTH ending), incl. a fall and quit/Continue
- [x] Performance: static batching (−55% draw calls), cached corridor shell (rebuild 56→18 ms), retuned presets (FSR 1), Auto quality that adapts on slow GPUs — `docs/PERFORMANCE.md`
- [x] Error sweep on both renderers; navmesh params snapped to grid; FSR only where supported; fades/awaits safe when a scene is freed; ending clears the save immediately
- [x] Logging on all platforms + "Open log folder"; version 0.8.0 on the title screen
- [x] Builds: Windows exe (`build_windows.cmd`, smoke-tested) and phone APK (`build_android.cmd`, arm64, 59 MB)
- [x] `tests/test_phase8.gd` — 44 checks; all suites: 279 pass
- [ ] Human playtest · phone test · release signing · store assets — see `docs/RELEASE_CHECKLIST.md`

## Phase 9 — real 3D models + recorded audio ✅ (v0.9.0)
- [x] 40 Poly Haven CC0 glTF models (1K PBR) dress every floor: desks, chairs, CRTs, sofa, brass puja items, kettle, day bed, fuse boxes, site machinery, floating junk… (`scripts/world/props.gd`, `kit.prop`); every placement keeps a primitive fallback
- [x] Rigged, motion-captured people from Microsoft Rocketbox (MIT): the Supervisor, the Floor 2 figure, Mother (faceless), the six workers, Papa, the Floor 6 shadow (`scripts/world/characters.gd`); idle/walk/run chosen from speed
- [x] Recorded sound bank (CC0 + CC-BY): footsteps per surface with random takes + pitch (incl. wet steps in Floor 5 puddles), knocks, door slam/creak, metal, splashes, heartbeat loop that speeds up with dread, stingers, rain, wind, room-tone beds per floor, tape deck, UI clicks; synth fallback kept
- [x] In-game Credits page (CC-BY authors, Rocketbox MIT notice, Godot licences) — `scripts/systems/credits.gd`; `docs/ASSET_LICENCES.md` rewritten
- [x] Model cache released when a floor exits (VRAM no longer accumulates every model across the climb)
- [x] `tests/test_assets.gd` — 46 checks; all suites: 325 pass
- [x] Perf re-profiled on Medium (Forward+) and the phone renderer — see Phase 10

## Phase 10 — visual overhaul ✅ (v0.10.0) — after the first hand playtest ("make it look much better")
- [x] Lighting: a shadow-casting downlight under every fixture (pools of light; follows flickers/blackouts), volumetric fog on Medium (torch beams, light shafts), reflection probe per room (glossy terrazzo, bounce-like ambient), stronger bloom, flashlight cookie without banding, torch that trails the view
- [x] Materials: per-texture normal tuning (the "cave rock" ceiling), new CC0 sets (terrazzo, painted plaster, plaster ceiling, glazed dado tiles, home tiles); rooms get skirting, cornices, door casings and optional tiled dado automatically
- [x] Decay: generated grime, damp, mould and floor-dirt decals placed per room (`tools/gen_fx_textures.py`)
- [x] Windows with Mumbai iron grilles, the night city outside (sky with sodium glow, instanced skyline), moonlight throwing the bars across the floor (G, 1, 4); Floor 5 gets a monsoon sky, raking moonlight and lightning (respects Reduced flashing)
- [x] Primitives replaced: panelled doors with lever handles, steel stair doors with wired glass, slatted reception counter, analog 3:33 clock, floor directory, lift surround, CRT phosphor shader, fridge, digital clock, bulbs; 11 more CC0 models (plants, desk lamps, cabinets, shelving, radio, broom, bin bag, toolbox, picture)
- [x] Budget kept: Medium ≤ 23.4 ms on the Intel UHD (SSAO moved to High; measured trade), heavy foliage excluded from shadows
- [x] Every test and capture script now protects the real save/settings (`tests/user_files.gd`)
- [x] `tests/test_visuals.gd` — 29 checks; all suites: 355 pass
## Phase 7 — touch controls, gyro, haptics, Android export
## Phase 8 — QA and release checklist
