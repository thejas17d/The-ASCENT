# Architecture
Everything is built from code + data so floors/anomalies/rules can be added without editor-only work.

| Path | Role |
|---|---|
| `scenes/menu.tscn` + `scripts/ui/menu.gd` | Title screen (main scene) |
| `scripts/autoload/game_state.gd` | **GameState**: floor, checkpoint, inventory, choices, falls, settings, save/load, input map |
| `scripts/autoload/graphics.gd` | **Graphics**: Low/Medium/High/Ultra presets, shared Environment (volumetric fog, SSAO/SSIL/SSR, glow, AgX) |
| `scripts/systems/mat_lib.gd` | PBR material library (world-triplanar CC0 textures, colour fallbacks) |
| `shaders/post_fx.gdshader` | Grain, vignette, dread aberration/pulse, VHS tear |
| `scripts/ai/supervisor.gd` | The Supervisor (see ENEMY_AI.md) |
| `scripts/floors/archive_test.gd` | Dev test level for the Supervisor (navmesh baked at runtime) |
| `scripts/ui/pause_menu.gd`, `settings_panel.gd`, `ui_theme.gd` | Pause, settings (user://settings.json), shared UI theme |
| `scripts/autoload/dread.gd` | **Dread**: 0–100, `tick()`, `add()`, `breakdown` signal, tiers |
| `scripts/floors/floor_base.gd` | **FloorBase**: player, HUD, director, audio, items, hiding, pickups, generic events. Hooks: `world_root`, `floor_lights`, `hide_spot`, `on_interact`, `on_breakdown`, `perform_floor_event` |
| `scripts/floors/floor_02.gd` + `scenes/floor_02.tscn` | Floor 2 rules, anomaly loop, knocking, Room 213 |
| `scripts/world/kit.gd` | **Kit**: modular builder every floor uses (rooms with openings, lamps, boards, doors, hide spots, items, notes, triggers) |
| `scripts/floors/floor_g.gd`, `floor_01.gd` … `floor_08.gd` | The eight floors (see FLOOR_DESIGN.md) |
| `scripts/floors/stairwell.gd` | Interlude between floors: story beat, voice memory, checkpoint |
| `scripts/ui/ending.gd` | ESCAPE / TRUTH endings, run summary, unlocks |
| `data/story/stairwell.json` | Stairwell wall texts + voice lines |
| `scripts/floors/corridor.gd` | Procedural corridor builder + `add_chalk/add_diya/add_pickup` |
| `scripts/player/player.gd` | FP controller, battery, phone (cull layer 2), hiding, breath, `noise` |
| `scripts/systems/event_director.gd` | Paranormal Event Director (reads `data/events/director.json`) |
| `scripts/systems/sfx.gd` | Procedural placeholder audio |
| `scripts/ui/hud.gd` | Prompt, messages, panel, dread vignette, status, breath bar, phone viewfinder |
| `data/…` | anomalies, floor rules, director events |

## Adding a floor
Create `scripts/floors/floor_NN.gd` extending `FloorBase`: `load_floor_data(N)`, build with `Kit.new(self)`, `setup_common()`, set `spawn`, `begin_floor()`. Implement hooks as needed: `on_use(id, node)`, `on_item_taken(id, node)`, `apply_checkpoint(cp)`, `on_breakdown()`, `surface_at(pos)`, `floor_lights()`. Call `unlock_exit()` when solved; `fall_down(reason)` / `die(reason)` on failure. Register the scene in `GameState.FLOOR_SCENES` and add a stairwell beat in `data/story/stairwell.json`.

## Adding a director event
Add an entry to `data/events/director.json`; generic ids are handled in `FloorBase.perform_event`, anything else goes to the floor's `perform_floor_event`. `fake: true` events must vanish within ~1 s (fairness rule: "what vanishes was never there").

## Adding an anomaly
Add to `data/anomalies/floor_02.json`, handle the id in `corridor.gd::build()`, run tests.
