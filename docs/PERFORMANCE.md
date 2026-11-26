# Performance (Phase 8)

Measured with `tests/perf.gd` (windowed, vsync off, 180 frames after a 60-frame warm-up) on this PC:
**Intel UHD Graphics (integrated), 1600×900**. Re-run any time:
`godot --path . -s res://tests/perf.gd -- <0-3>` · phone renderer: add `--rendering-method mobile`.

## Frame time per preset (average ms across floors G–8)
| Preset | Before Phase 8 | After Phase 8 | ≈ fps on this iGPU | What changed |
|---|---|---|---|---|
| Low | 10–12 | 10–12 | 85–100 | FSR 1 upscale (sharper at same cost) |
| Medium | 24–30 | **20–22** | 45–50 | FSR 1 at 0.8 instead of 0.9 + MSAA 2×; very-low half-res SSAO |
| High | 39–42 | **29–38** | 26–34 | medium SSAO, 64³ volumetric fog |
| Ultra | 63–105 | 62–89 | 11–16 | MSAA 2× instead of 4× (meant for discrete GPUs) |
| Phone renderer, Medium | 13–22 | 14–21 | 47–70 | — |

**Auto quality** (Settings → Graphics quality → Auto, the default): integrated GPUs (Intel/UHD/Iris/Radeon Graphics/Vega/Adreno/Mali…) start on **Medium**, discrete GPUs on **High**. During play, if any 4-second window averages slower than 25 ms (< 40 fps), it drops one preset, says so on screen, and remembers it (`auto_level`). Picking a preset by hand turns Auto off.

## v0.11 (windows on 6/7, stairwell decals + probe, fonts, opening scene) — Intel UHD, 1600×900, Medium
| | menu | intro | G | stair | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Forward+ avg ms | 13.2 | 9.7 | 16.9 | 14.2 | 17.4 | 12.6 | 14.4 | 16.4 | 14.9 | 13.7 | 14.4 | 11.9 | 8.9 |
| Phone renderer avg ms | 10.4 | 6.4 | 13.1 | 13.2 | 16.0 | 8.8 | 13.7 | 15.1 | 11.8 | 13.7 | 13.1 | 8.7 | 5.0 |

This run was ~25 % faster than the v0.10 run below on the same scenes — the PC's load varies between
runs (background apps, thermals), so read both as a range: Medium sits between ~9 and ~23 ms on this
iGPU. One 57 ms spike on Floor 6 (phone renderer, max) — a shader compile on first sight of the windows.

## v0.10 visual overhaul (measured on this PC: Intel UHD, 1600×900, Medium)
New at Medium: volumetric fog (48³, torch beams + light shafts), moonlight with shadows through
windows / open sides, per-room reflection probes, ~30–45 decals per room, downlights under every
fixture, the skyline. To pay for it, **SSAO moved from Medium to High** — measured per feature
on Floor G before the trade: SSAO 4.2 ms, moon shadows 3.7 → 1.2 ms (one cascade, 28 m, 2K map),
fog 1.8, reflection probe 1.8, downlights 1.6 (their shadows are High+ only), decals ≈ 0.

Forward+, **Medium**, avg ms per scene (one run):

| menu | G | stair | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 17.5 | 22.9 | 17.3 | 23.4 | 16.8 | 19.1 | 22.4 | 19.6 | 16.2 | 17.4 | 15.5 | 11.8 |

All under Auto quality's 25 ms line (≈ 43–85 fps), but the margin on G / 1 / 4 is only ~2 ms:
a slower iGPU would step down to Low there. p95 up to 27 ms.

Phone renderer, Medium (two runs — this iGPU is noisy on it): 6.8–21.4 ms in the second run
(G 18.2, 1 20.9, 4 21.4); the first run read 7.6–28.7 ms. VRAM 540–870 MB (Forward+ Medium).
Not re-measured: High and Ultra (meant for discrete GPUs), real phones.

Re-run: `godot --path . -s res://tests/perf.gd -- 1` · `godot --rendering-method mobile --path . -s res://tests/perf.gd -- 1`.

## Draw calls
| | Before | After |
|---|---|---|
| Floor 1 (Ultra / others) | 1209 / 514 | 565 / 237 |
| Floor 2 corridor | 1054 / 687 | 483 (all presets) |
| Typical floor | 300–900 | 180–480 |

`scripts/systems/batcher.gd` merges static, opaque level geometry into one mesh per material per 8 m cell (world-space triplanar textures make this visually identical; cells keep culling and the Mobile renderer's 8-lights-per-object limit working). Moving/interactive things are excluded by metadata (`use`, `item`, `door_index`, `dynamic`, …).

## Hitches
- Floor 2 corridor rebuild between passes: 56 ms → **18 ms** (static shell built + batched once per Room 213 state; only doors/props/anomalies rebuilt). Happens during the black fade.
- Floor loads: 150–700 ms (batching adds ~100–400 ms, during the fade-in).

## Memory
VRAM 120 MB (Low) → 300 MB (Medium) → 430 MB (High) → 750–1100 MB (Ultra, 8K shadow atlas). Phones: 1K textures, ~290 MB.

## Not measured
Real phones (no device connected). The phone renderer on this iGPU suggests mid-range phones should hold 30–60 fps on Medium; verify on hardware.
