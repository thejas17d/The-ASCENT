# THE SUPERVISOR — enemy AI

`scripts/ai/supervisor.gd` · tuning in `data/ai/supervisor.json` · test level `scenes/dev/supervisor_test.tscn` (title menu → "Test: The Supervisor").

## Fairness contract
| The player can always rely on… | How |
|---|---|
| Knowing its state | Helmet lamp: dim yellow = patrol, **amber** = noticed / investigating / searching, **red** = chasing |
| A warning before a chase | It always stops and stares (amber, 0.8 s) before chasing — unless you're within 4 m |
| Hearing it coming | Heavy footsteps audible to ~20 m; faster cadence when chasing; subtitles for both |
| No cheap spawns | `safe_spawn_point()` rejects points within 12 m or in your line of sight |
| Walls block sight | Ray from its eyes to your chest on the world layer only |
| Hiding works | Unless it **saw you get in**, or it has **learned** that kind of spot (it tells you: "it has started checking the lockers first") |

## Senses (per floor: `senses = {sight, sound, light}`)
- **Sight**: 110° FOV, 13 m (22 m if your torch is on, ×0.6 when crouched), needs line of sight; a 1.6 m proximity sense ignores FOV.
- **Sound**: `player.noise × 18 m` (×0.55 through walls). Noise: run 1.0, walk 0.3, crouch 0.1, still 0.05, hidden 0.1, holding breath 0.0, gasp burst 0.9.
- **Light**: your torch beam pointed at it (within the cone, with line of sight).

Floor 5 ("It hunts by light / by sound — one is false") disables one sense, chosen per playthrough.

## State machine
```
DORMANT → PATROL ⇄ SUSPICIOUS → INVESTIGATE → SEARCH → RETURN → PATROL
                         └──────────→ CHASE ──→ ATTACK (caught_player)
                                        └── lost for 4 s → SEARCH
```
- Awareness 0–1.5: sight/light raise it continuously; a sound snaps it to 0.5 (0.75 if loud) with an imprecise last-known position; it decays at 0.12/s.
- **Search** visits up to 3 hiding spots within 11 m of where it lost you, **learned kinds first**, then nearest, checking each for 1.6 s.
- **Learning**: every hide is remembered per kind (`hide_memory`). At 3 uses of a kind it emits `learned(kind)`; from then on a breath-holding player in that kind of spot is found.
- Awareness is capped on entering SEARCH (0.7) and RETURN (0.2) so leftover alarm can't bounce it back.

## Movement
NavigationAgent3D on a navmesh baked at runtime from static colliders (`PARSED_GEOMETRY_STATIC_COLLIDERS`). Speeds: patrol 1.3, search 1.8, investigate 2.1, chase 4.4 m/s. You run at 5.2, so you can outrun it, but running is loud.

## Integrating on a floor
```gdscript
sup = Supervisor.new(); add_child(sup)
sup.player = player; sup.hide_spots = spots; sup.waypoints = [...]
sup.senses = {"sight": true, "sound": false, "light": true}
sup.caught_player.connect(_on_caught)
sup.activate(sup.safe_spawn_point(points, player.global_position, get_world_3d().direct_space_state))
```
Hide spots are `Node3D` markers with meta `hide_kind` (e.g. "locker", "desk") and `eye` (camera height); their **-Z faces out** of the hiding place. Interactables carry meta `hide` + `hide_spot`; `FloorBase.on_player_hid()` forwards to `note_player_hid()`.

## Known limitations
- The body is built from primitives (capsules + hemisphere helmet) with procedural limb swing. A rigged, animated model is a future art task.
- Single entity; it can't open doors yet (floors with doors will need navigation links).
