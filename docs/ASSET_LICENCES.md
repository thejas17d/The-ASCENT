# Asset licences

## Textures — Poly Haven (CC0 1.0, public domain)
Source: https://polyhaven.com — "All assets are CC0: no attribution required, free for commercial use."
Downloaded at 2K (albedo, normal GL, roughness, AO) into `assets/textures/<id>/`.

| Asset id | Used for | Page |
|---|---|---|
| decrepit_wallpaper | corridor walls, Room 213 | https://polyhaven.com/a/decrepit_wallpaper |
| peeling_painted_wall | lobby walls | https://polyhaven.com/a/peeling_painted_wall |
| dirty_carpet | corridor carpet | https://polyhaven.com/a/dirty_carpet |
| old_mosaic_floor | lobby floors | https://polyhaven.com/a/old_mosaic_floor |
| ceiling_interior | ceilings | https://polyhaven.com/a/ceiling_interior |
| sapele_veneer | doors, wainscot, trims, furniture | https://polyhaven.com/a/sapele_veneer |
| rusty_painted_metal | almirah, stair door, brackets | https://polyhaven.com/a/rusty_painted_metal |
| plywood | notice board, chairs, shelving | https://polyhaven.com/a/plywood |
| concrete_floor_worn_001 | archive / construction floors | https://polyhaven.com/a/concrete_floor_worn_001 |

Import settings: VRAM compressed + mipmaps (normal maps flagged as normal maps). ETC2/ASTC enabled for Android.

## Generated in code (no licence needed)
- All geometry (boxes, cylinders, capsules) — `scripts/floors/*.gd`
- Painting canvases (FastNoiseLite), stains (gradient decals), torch beam pattern
- All audio (procedural synthesis) — `scripts/systems/sfx.gd`
- Post-processing shader — `shaders/post_fx.gdshader`

Record every future asset here: name, source URL, author, licence, files.
