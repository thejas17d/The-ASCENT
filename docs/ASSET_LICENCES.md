# Asset licences

Every third-party file in the game, where it came from, and what its licence asks of us.
The in-game **title screen → Credits** shows the same attributions plus the full MIT notices
(Rocketbox, Godot) — CC-BY and MIT require the credit in the *shipped* game, not just here.
Source of truth for that screen: `scripts/systems/credits.gd`. Keep both in sync.

| Licence | What it asks | Used for |
|---|---|---|
| CC0 1.0 | nothing (public domain) | textures, 3D models, most sounds |
| MIT | keep the copyright + permission notice with every copy | Rocketbox characters + mocap; Godot Engine |
| CC-BY 3.0 / 4.0 | credit the author, link the licence, say if changed | tile/water footsteps, knock + door slam, wind, building room tone |

---

## Textures — Poly Haven (CC0 1.0)
Source: https://polyhaven.com — "All assets are CC0: no attribution required, free for commercial use."
2K maps (albedo, normal GL, roughness, AO) in `assets/textures/<id>/`.

| Asset id | Used for |
|---|---|
| decrepit_wallpaper | corridor walls, Room 213 |
| peeling_painted_wall | lobby walls |
| dirty_carpet | corridor carpet |
| old_mosaic_floor | lobby floors |
| ceiling_interior | ceilings |
| sapele_veneer | doors, wainscot, trims, furniture |
| rusty_painted_metal | almirah, stair door, brackets |
| plywood | notice board, shelving |
| concrete_floor_worn_001 | archive / construction floors |

Pages: `https://polyhaven.com/a/<id>`. Import: VRAM compressed + mipmaps (normal maps flagged), ETC2/ASTC for Android.

## 3D models — Poly Haven (CC0 1.0)
glTF with 1K PBR textures in `assets/models/<id>/<id>_1k.gltf` (40 models, ~65 MB on disk).
Loaded by `scripts/world/props.gd` (fit-to-size, box collider); placed with `kit.prop(...)`.
Every placement has a primitive fallback, so a missing model never breaks a floor.
Pages: `https://polyhaven.com/a/<id>`.

| Model | Where |
|---|---|
| metal_office_desk | every desk (`kit.desk`), Floor G booth |
| SchoolChair_01, painted_wooden_chair_02 | every chair (`kit.chair`, office / home style) |
| security_light | construction work lamps (`kit.lamp "work"`) |
| Sofa_01 | Floor G waiting area, Floor 4 living room |
| WetFloorSign_01 | Floor G, Floor 3 |
| security_camera_01, vintage_telephone_wall_clock | Floor G |
| fire_alarm | Floor G, Floor 1, stairwell |
| korean_fire_extinguisher_01 | Floor G, corridor, Floor 1, Floor 3, stairwell |
| cardboard_box_01 | Floor G, Floor 1, Floor 3, Floor 7 |
| ceiling_fan | Floor G, Floor 4 |
| television_02, stationery_supplies, clipboard | Floor 1 (CRTs, desks) — clipboard also Floor 3 |
| WoodenTable_01 | Floor 1 meeting table, Floor 4 dining table |
| side_table_01, ceramic_vase_01, painted_wooden_chair_01 | corridor; side table also Floor 4 |
| power_box_01 | Floor 3 fuse boxes |
| Television_01, portable_cassette_player | Floor 4 (TV, the tape deck) |
| brass_diya_lantern, brass_pot_01, brass_vase_04, pot_enamel_01, vintage_electric_kettle | Floor 4 kitchen / puja shelf |
| wooden_bookshelf_worn, painted_wooden_cabinet, standing_picture_frame_01, vintage_day_bed | Floor 4 |
| cement_bag, Barrel_01, old_tyre, propane_tank, portable_generator, metal_jerrycan_green, plastic_crate_02, sledgehammer_01 | Floor 5 site; most also float on Floor 7 |
| utility_box_01 | Floor 8 roof |

## Characters and motion capture — Microsoft Rocketbox (MIT)
Source: https://github.com/microsoft/Microsoft-Rocketbox — **Copyright (c) 2020 Microsoft**, MIT licence.
Full text: `assets/characters/LICENSE_Rocketbox.md` (also printed in-game under Credits).

| Avatar | Role |
|---|---|
| Construction_Male_02 | The Supervisor (dark-tinted, 2.08 m), the Floor 2 figure |
| Construction_Male_04, Construction_Male_07 | the six Floor 7 workers |
| Female_Adult_02 | Mother on Floor 4 (faceless head — material override) |
| Male_Adult_03 | Papa on Floor 8; the Floor 6 shadow (black translucent override) |

Mocap clips (`assets/characters/anims/`): m_idle_neutral_01, f_idle_neutral_01, m_walk_slow_01,
m_walk_neutral_01, m_run_neutral, f_walk_neutral_01. Same 82-bone Biped skeleton, so no retargeting.

Changes made: 2048 TGA textures converted to 1024 JPG/PNG; materials rebuilt in code
(`scripts/world/characters.gd`); tinted / re-scaled per role.

## Sound

### CC-BY — attribution required
| Files | Work | Author | Licence | Link |
|---|---|---|---|---|
| `steps/tile/*` | "Footsteps on different surfaces" (tile) | congusbongus; derived from "footstep-concrete.wav" by **swuing** (freesound #38873) and "Squeaky footstep.wav" by **ceberation** (freesound #235524) | CC-BY 3.0 | https://opengameart.org/content/footsteps-on-different-surfaces |
| `steps/water/*` | same pack (water) | congusbongus; derived from "Water Footsteps" by **EminYILDIRIM** (freesound #608663) and swuing | CC-BY 3.0 | as above |
| `doors/knocking.wav`, `doors/doorslam.wav` | "25 spooky sound effects" | **Bart** — the page asks for a link back to http://opengameart.org | CC-BY 3.0 | https://opengameart.org/content/25-spooky-sound-effects |
| `loops/wind_loop.ogg` | "Wind Loop" | Created by **Jonathan Shaw (InspectorJ)** (https://freesound.org/people/InspectorJ/sounds/376415/), looped by antumdeluge | CC-BY 3.0 | https://opengameart.org/content/wind-loop |
| `loops/abandoned_building.wav` | "Abandoned Building Ambience" | **tcarisland** | CC-BY 3.0 | https://opengameart.org/content/abandoned-building-ambience |

Licence texts: https://creativecommons.org/licenses/by/3.0/ · https://creativecommons.org/licenses/by/4.0/
Per-folder licence notes from the packs are kept in `assets/audio/licences/`.
Changes made: trimmed, re-pitched at runtime (random pitch), layered and mixed.

### CC0 — no attribution required (credited anyway)
| Files | Work | Author |
|---|---|---|
| `steps/carpet/*`, `steps/concrete/*`, `impacts/impactMetal_heavy_*` | Impact Sounds | Kenney (kenney.nl) |
| `doors/creak*`, `doors/metalLatch.ogg` | RPG Audio | Kenney |
| `ui/click_*` | Interface Sounds | Kenney |
| `body/heartbeat_slow.wav` | Heartbeat | Bart (opengameart.org) |
| `ambience/rain_1.ogg` | Rain (loopable) | ylmir |
| `loops/ambient_horror.ogg` | Ambient horror | techiew |
| `impacts/metal_*` | 100 CC0 metal and wood SFX | rubberduck |
| `water/splash_*` | Water splash / slime SFX | rubberduck |
| `stingers/Very_Bassy_*` | Horror Hit Soundpack 1 | psychhead |
| `misc/distant_boom.wav` | Muffled Distant Explosion | NenadSimic |
| `misc/tape_open.wav` | Tape recorder opening | Spring Spring |

### Still generated in code (`scripts/systems/sfx.gd`)
Fluorescent hum, phone ring, whispers, gasp, the footsteps-behind-you, UI tick. Every recorded id
also keeps a synth fallback, so a missing file degrades to the old sound instead of silence.

## Godot Engine (MIT)
Copyright (c) 2014-present Godot Engine contributors; (c) 2007-2014 Juan Linietsky, Ariel Manzur.
The Credits screen prints `Engine.get_license_text()`, `Engine.get_copyright_info()` and
`Engine.get_license_info()` at runtime, so the engine's own notice and its third-party
components (FreeType, ENet, mbedTLS, …) always match the exported engine version.

## Generated in code (no licence needed)
- Level geometry (walls, floors, stairs, doors, notice boards), stains, painting canvases, torch pattern
- Post-processing shader — `shaders/post_fx.gdshader`

---
**Record every future asset here:** file path, source URL, author, licence, what was changed —
and add it to `scripts/systems/credits.gd` if the licence requires attribution.
