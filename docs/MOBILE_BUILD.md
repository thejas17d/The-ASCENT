# Mobile & Android build (Phase 7)

## Install on your phone (quickest)
1. On the phone: Settings → About → tap *Build number* 7× → Developer options → **USB debugging ON**.
2. Plug it in by USB, accept the "Allow USB debugging?" prompt.
3. Double-click **`build_android.cmd`** — it builds `build/TheAscent.apk` and runs `adb install -r` on it.

Or copy `build/TheAscent.apk` to the phone and open it (allow "install unknown apps").

## What's set up (this PC)
| Piece | Where |
|---|---|
| Godot 4.4.1 | `%USERPROFILE%\.godot\` |
| Android export templates (debug + release APKs only; source/gradle template not installed) | `%APPDATA%\Godot\export_templates\4.4.1.stable\` |
| Android SDK (build-tools 36/37, platform 36) + JDK 21 | `%USERPROFILE%\.android-toolchain\` |
| Debug keystore (standard `androiddebugkey` / `android`) | `%USERPROFILE%\.android\debug.keystore` |
| Godot editor settings pointing at the above | `%APPDATA%\Godot\editor_settings-4.4.tres` (`export/android/*`) |
| Export preset | `export_presets.cfg` → "Android" |

Manual build: `"%USERPROFILE%\.godot\Godot_v4.4.1-stable_win64_console.exe" --headless --path . --export-debug "Android" build/TheAscent.apk`

## Export preset
- Package `com.meridian.theascent`, version 0.7.0 (code 1), signed with the debug key.
- Architectures: **arm64-v8a** (phones) + **x86_64** (emulators). For a store/release build drop x86_64 (−80 MB).
- Landscape (sensor), immersive full-screen, **VIBRATE** permission.
- Exports `*.json` data (non-resource files) and **excludes the 2K textures** — phones use the 1K set (`assets/textures_1k/`, 21 MB of JPGs, ETC2/ASTC-compressed on import). APK ≈ 86 MB (target was < 300 MB).
- Renderer on phones: **Mobile** (`rendering_method.mobile`). No volumetric fog/SSAO/SSIL/SSR there — `Graphics` skips them automatically; default preset Medium.

## Touch controls
Automatic on phones (Settings → Mobile → Touch controls: Auto / Always / Never; *Always* lets you try them on desktop).
- **Left 40%**: floating joystick appears under your thumb; push to the edge to **run**.
- **Right side**: drag to look (Settings → Touch look sensitivity).
- Buttons (true multi-touch `TouchScreenButton`s mapped to the same input actions as the keyboard): **USE**, **TORCH**, **CROUCH** (toggle), **HOLD BREATH** (only while hiding), **PHONE**, **DIYA**, **VOICE**, **BATT**, **BAG**, **II** (pause).
- Prompts say "USE ·" instead of "[E]"; the keypad never pops up the OS keyboard.
- **Gyroscope look** (Settings, off by default) — assumes Godot's screen-space gyro values; *not yet verified on hardware*: if it turns the wrong way on your phone, tell me and I'll flip the axis.
- **Vibration** (Settings, on): heartbeat at high dread, the Supervisor starting a chase, gasps, knocking, falls, death.
- UI scales with resolution (`canvas_items` stretch, base 1600×900) — also keeps the HUD readable at 4K.

## Not verified yet
- **On a real phone**: performance (the 60 fps target), gyro axes, haptic strength, button reach on different screen sizes. No device was connected and no emulator system image is installed (an x86_64 image is ~1.5 GB if we want one — the AVD tooling is ready, WHPX acceleration works on this PC).
- Release signing: needs your own keystore (never commit it) — `export/android/release_keystore*` in editor settings, then `--export-release`.
- iOS: needs a Mac + Xcode; not started.
