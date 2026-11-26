# THE ASCENT — v0.11.0
First-person paranormal survival horror (Godot 4.4, GDScript, Mobile renderer).
Climb Meridian Tower, Mumbai — every floor has rules, and some of them lie.

## Run
- Double-click `play.cmd`, or in cmd: `"%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64.exe" --path .`
- Edit: open the folder in the Godot 4.4.1 editor (`~/.godot/Godot_v4.4.1-stable_win64.exe -e --path .`).
- Tests: see `docs/TESTING.md` (376 headless checks incl. an end-to-end playthrough)
- **Android**: plug in a phone with USB debugging and double-click `build_android.cmd` (see `docs/MOBILE_BUILD.md`)
- **Windows build**: `build_windows.cmd` → `build/windows/TheAscent.exe`
- Release status: `docs/RELEASE_CHECKLIST.md` · performance: `docs/PERFORMANCE.md`

## Controls (desktop — phones get on-screen touch controls automatically)
WASD move · Mouse look · Shift run · Ctrl crouch · E interact · F flashlight · R battery · C chalk · G diya · Q phone camera · V voice note · Space hold breath (hiding) · Tab inventory · Esc pause · F11 fullscreen

## Current state
**The whole ascent is playable:** Floor G to the roof (8 floors + stairwell interludes), two endings. Real assets: 40 CC0 3D models (Poly Haven), rigged motion-captured characters (Microsoft Rocketbox, MIT) and recorded sound (CC0 / CC-BY) — credits on the title screen, sources in `docs/ASSET_LICENCES.md`. PBR visuals with Low→Ultra/UHD presets, the Supervisor AI, save/checkpoints, dread, items, hiding, pause/settings. Replayability: Night Shift / New Game+, Daily Corridor, hidden Floor 9, a Memories journal (see `docs/REPLAYABILITY.md`). Title menu also has a Supervisor test level. See `docs/DEVELOPMENT_ROADMAP.md`.
Docs: `docs/FLOOR_DESIGN.md`, `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/ENEMY_AI.md`, `docs/TESTING.md`, `docs/ASSET_LICENCES.md`.
