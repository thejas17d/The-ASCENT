# Architecture
Everything is built from code + data so floors/anomalies/rules can be added without editor-only work.

| Path | Role |
|---|---|
| `scenes/main.tscn` | Entry scene (one node + `scripts/main.gd`) |
| `scripts/main.gd` | Floor 2 controller: pass loop, judgement, rules, knocking, dread, win |
| `scripts/floors/corridor.gd` | Procedural corridor builder; `build(anomaly, streak, open_213, seed)` |
| `scripts/player/player.gd` | First-person CharacterBody3D, flashlight, interact ray (`interacted` signal) |
| `scripts/ui/hud.gd` | Prompt, messages, rule panel, dread vignette, fades |
| `scripts/systems/sfx.gd` | Procedural placeholder audio (knock, hum, sting) |
| `data/anomalies/*.json` | Anomaly pool per floor |
| `data/floor_rules/*.json` | Rule boards (text, class true/false/incomplete, truth, clue) |
| `tests/` | Headless logic tests + screenshot helper |

## Adding an anomaly
1. Add `{id, desc, dread}` to `data/anomalies/floor_02.json`.
2. Handle the `id` in `corridor.gd::build()`.
3. Run tests — every anomaly must visibly change the corridor or the test fails.

## Planned refactor (before Floor 3)
Split `main.gd` into autoloads: `GameState` (floor, choices, save), `DreadSystem`, `RuleSystem`, `EventDirector`, and a `Floor` base class each floor scene extends. Kept monolithic for now to prove the loop first.
