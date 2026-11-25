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

## After Phase 9 (real models, rigged characters, recorded audio)
Forward+, **Medium**, same PC (Intel UHD, 1600×900), per scene — avg / p95 ms:

| menu | G | stair | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 16.7 / 17.8 | 17.3 / 18.7 | 15.3 / 16.3 | 18.3 / 19.2 | 15.4 / 16.5 | 17.0 / 18.0 | 17.9 / 19.3 | 16.9 / 19.1 | 16.6 / 21.2 | 18.5 / 20.4 | 14.4 / 15.6 | 9.3 / 11.1 |

So Medium stays at **≈ 55–65 fps** on this iGPU with the real assets (Phase 8 measured 20–22 ms across floors). Draw calls 158–479 (batching still applies to the shell; each model adds a few calls).

**VRAM** climbed during that run: 302 MB (menu) → 463 MB (Floor 5) → 817–843 MB (Floors 6–9), versus 271 → 295 → 475 MB in Phase 8. Part of the Floor 6 jump existed before; the rest was the prop loader's static cache keeping every model ever loaded resident. Fixed afterwards: leaving a floor now releases the cache (`Props.release()`, tested) — **not yet re-measured**.

**Not measured yet:** High (the partial run showed 37–57 ms on G–3, but it ran while the PC was almost out of RAM, so it is not trustworthy), Ultra and the phone renderer. The profile run was stopped by the system for low memory (Chrome was using ~4 GB). Re-run when RAM is free:
`godot --path . -s res://tests/perf.gd -- 2` and `godot --rendering-method mobile --path . -s res://tests/perf.gd -- 1`.

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
