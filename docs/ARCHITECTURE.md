# Architecture
Everything is built from code + data so floors/anomalies/rules can be added without editor-only work.

| Path | Role |
|---|---|
| `scenes/menu.tscn` + `scripts/ui/menu.gd` | Title screen (main scene) |
| `scripts/autoload/game_state.gd` | **GameState**: floor, checkpoint, inventory, choices, falls, settings, save/load, input map |
| `scripts/autoload/dread.gd` | **Dread**: 0–100, `tick()`, `add()`, `breakdown` signal, tiers |
| `scripts/floors/floor_base.gd` | **FloorBase**: player, HUD, director, audio, items, hiding, pickups, generic events. Hooks: `world_root`, `floor_lights`, `hide_spot`, `on_interact`, `on_breakdown`, `perform_floor_event` |
| `scripts/floors/floor_02.gd` + `scenes/floor_02.tscn` | Floor 2 rules, anomaly loop, knocking, Room 213 |
| `scripts/floors/corridor.gd` | Procedural corridor builder + `add_chalk/add_diya/add_pickup` |
| `scripts/player/player.gd` | FP controller, battery, phone (cull layer 2), hiding, breath, `noise` |
| `scripts/systems/event_director.gd` | Paranormal Event Director (reads `data/events/director.json`) |
| `scripts/systems/sfx.gd` | Procedural placeholder audio |
| `scripts/ui/hud.gd` | Prompt, messages, panel, dread vignette, status, breath bar, phone viewfinder |
| `data/…` | anomalies, floor rules, director events |

## Adding a floor
Create `scripts/floors/floor_NN.gd` extending `FloorBase`, build geometry in `_ready()`, call `setup_common()`, implement the hooks, add the scene to `GameState.FLOOR_SCENES`.

## Adding a director event
Add an entry to `data/events/director.json`; generic ids are handled in `FloorBase.perform_event`, anything else goes to the floor's `perform_floor_event`. `fake: true` events must vanish within ~1 s (fairness rule: "what vanishes was never there").

## Adding an anomaly
Add to `data/anomalies/floor_02.json`, handle the id in `corridor.gd::build()`, run tests.
