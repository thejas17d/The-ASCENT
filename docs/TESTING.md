# Testing
Run from the project folder (Git Bash shown; in cmd use `"%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64_console.exe"`):

| Suite | Command | Checks | Last run |
|---|---|---|---|
| Floor 2 + core systems | `godot --headless --path . -s res://tests/test_floor2.gd` | 68 | 68/68 pass |
| Supervisor AI | `godot --headless --path . -s res://tests/test_supervisor.gd` | 23 | 23/23 pass |
| All floors G–8, stairwell, flow | `godot --headless --path . -s res://tests/test_floors.gd` | 85 | 85/85 pass |
| Night Shift, NG+, voice notes, Memories, Daily, Floor 9, menu, endings | `godot --headless --path . -s res://tests/test_phase6.gd` | 31 | 31/31 pass |
| Touch joystick/look/buttons, crouch toggle, gyro, haptics, 1K textures, settings, stretch | `godot --headless --path . -s res://tests/test_mobile.gd` | 28 | 28/28 pass |

Mobile renderer screenshot with the touch overlay: `godot --rendering-method mobile --path . -s res://tests/mobile_shot.gd`.

Both back up and restore your real `user://save.json` / `settings.json`.

**Floor 2** covers: every anomaly changes the scene; no prop/decal inside a door; judgement logic; Room 213; the figure never vanishes; pickups/notes never in the judged corridor; knock grace; hiding clears running; save/load including malformed and corrupt files; breakdown checkpointing; battery/chalk/diya; dread rise/fall/breakdown; phone layer + clue placement; hiding/breath (exactly one gasp); panel closing; notes; director gating/cooldowns; every event; all 4 quality presets; settings persistence.

**Supervisor** covers: navmesh bake, patrol, sight + amber warning beat, walls block sight, hearing through shelves, crouch stealth, torch-beam detection, blind mode, catch, lose → search → return, learning + search priority, breath-holding vs learned spots, fair spawn.

**All floors** plays each puzzle to completion through the floors' own methods and checks every rule's consequence (falls to the right floor, deaths restart the right floor, checkpoints restore), both endings, the Floor 9 unlock, stairwell story beats and floor-to-floor flow. Scene changes are intercepted via `GameState.test_mode`.

Screenshot helpers (windowed): `tests/floor_shot.gd -- <g|stair|1|3|4|5|6|7|8>`, `tests/shot.gd -- <quality 0-3> <tag>`, `tests/menu_shot.gd`, `tests/sup_shot.gd`; images land in `%APPDATA%/Godot/app_userdata/The Ascent/`.

Not yet tested: a real human playtest, touch devices, Android performance.
