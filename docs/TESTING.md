# Testing
Run from the project folder (Git Bash shown; in cmd use `"%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64_console.exe"`):

| Suite | Command | Checks | Last run |
|---|---|---|---|
| Floor 2 + core systems | `godot --headless --path . -s res://tests/test_floor2.gd` | 68 | 68/68 pass |
| Supervisor AI | `godot --headless --path . -s res://tests/test_supervisor.gd` | 23 | 23/23 pass |
| All floors G–8, stairwell, flow | `godot --headless --path . -s res://tests/test_floors.gd` | 85 | 85/85 pass |
| Night Shift, NG+, voice notes, Memories, Daily, Floor 9, menu, endings | `godot --headless --path . -s res://tests/test_phase6.gd` | 31 | 31/31 pass |
| Touch joystick/look/buttons, crouch toggle, gyro, haptics, 1K textures, settings, stretch | `godot --headless --path . -s res://tests/test_mobile.gd` | 28 | 28/28 pass |
| Review-2 regressions + **end-to-end playthrough** (real scene changes: title → G…8 → ending, a fall, quit/Continue) | `godot --headless --path . -s res://tests/test_phase8.gd` | 44 | 44/44 pass |
| Real assets: every CC0 model loads with a collider, fit-to-size, characters + mocap, floors use them, every recorded sound, wet puddle steps, model cache released per floor, in-game credits | `godot --headless --path . -s res://tests/test_assets.gd` | 46 | 46/46 pass |
| Visuals (v0.10–0.11): room decals / probe / trim, windows with colliders, night sky + moon (none on Low), downlights follow their lamps, shadow budget per preset, torch cookie, analog clock, foliage without shadows, CRT shader, lightning vs Reduced flashing, material tuning, see-through glass; fonts + their licences, title cards, typed documents, battery gauge, almirahs, archive boxes, cork boards, per-floor acoustics, windows on 6/7, paan-stained stairwell, the Supervisor's stare + reach (hands verifiably move), Mother's head-turn, the opening scene and its skip | `godot --headless --path . -s res://tests/test_visuals.gd` | 49 | 49/49 pass |

**Total: 376 checks, all passing (v0.11.0).** Every suite and every screenshot/perf script backs up and restores your real `save.json`, `settings.json`, `unlocks.json` and `daily.json` (`tests/user_files.gd`) — running them never touches a real playthrough. The backup is written to `user://.test_backup/` first, so even a crashed or killed run is undone by the next one. Performance: `tests/perf.gd` (see `docs/PERFORMANCE.md`).

Mobile renderer screenshot with the touch overlay: `godot --rendering-method mobile --path . -s res://tests/mobile_shot.gd`.

Both back up and restore your real `user://save.json` / `settings.json`.

**Floor 2** covers: every anomaly changes the scene; no prop/decal inside a door; judgement logic; Room 213; the figure never vanishes; pickups/notes never in the judged corridor; knock grace; hiding clears running; save/load including malformed and corrupt files; breakdown checkpointing; battery/chalk/diya; dread rise/fall/breakdown; phone layer + clue placement; hiding/breath (exactly one gasp); panel closing; notes; director gating/cooldowns; every event; all 4 quality presets; settings persistence.

**Supervisor** covers: navmesh bake, patrol, sight + amber warning beat, walls block sight, hearing through shelves, crouch stealth, torch-beam detection, blind mode, catch, lose → search → return, learning + search priority, breath-holding vs learned spots, fair spawn.

**All floors** plays each puzzle to completion through the floors' own methods and checks every rule's consequence (falls to the right floor, deaths restart the right floor, checkpoints restore), both endings, the Floor 9 unlock, stairwell story beats and floor-to-floor flow. Scene changes are intercepted via `GameState.test_mode`.

Screenshot helpers (windowed): `tests/floor_shot.gd -- <g|stair|1|3|4|5|6|7|8>`, `tests/shot.gd -- <quality 0-3> <tag>`, `tests/menu_shot.gd`, `tests/sup_shot.gd`; images land in `%APPDATA%/Godot/app_userdata/The Ascent/`.

**Assets** covers: all 40 Poly Haven models load as StaticBody3D with a box collider; fit-to-size scales model and collider together; a missing model returns null (callers fall back to primitives); all 5 Rocketbox avatars have the 82-bone skeleton, every surface textured and a mocap walk playing; the 6 clips loop; the Supervisor, Mother and all six workers are real characters in-game and the Supervisor walks with the mocap cycle; Floor 1 has > 40 model instances; Floor 5 puddles give wet footsteps; leaving a floor releases its cached models; 18 sound ids use recordings (randomised takes + pitch for steps); hum/ring stay synthesised; loops loop; every button clicks; the Credits page shows every CC-BY author, the Rocketbox MIT notice and Godot's licences.

Not yet tested: a real human playtest, touch devices, Android performance.
