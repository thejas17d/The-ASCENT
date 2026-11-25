# Release checklist — v0.10.0

Legend: ✅ done & verified · 🟡 done, needs a human/device check · ⬜ not done (needs you)

## Build
- ✅ Version 0.10.0 (project + Android versionCode 4 + Windows file version)
- ✅ Windows build: `build_windows.cmd` → `build/windows/TheAscent.exe` (97 MB) + `TheAscent.pck` (464 MB, nearly all textures). Smoke-tested headless for 0.10.0: starts, exit 0, no errors in log.
- ✅ Android phone APK: `build_android.cmd` → `build/TheAscent-phone.apk` (arm64, **≈ 295 MB**, debug-signed) + installs via adb.
- ⬜ **Build an app bundle (AAB) for Play** — Play takes AABs (APK uploads are capped at the legacy 100 MB). Needs Godot's gradle build: install the Android build template (Project → Install Android Build Template) and export with format AAB. At ≈ 295 MB the game is within Play's 500 MB base-module limit; installs over 200 MB on mobile data get a non-blocking size warning (`docs/MOBILE_BUILD.md`).
- 🟡 Android emulator APK (`Android` preset, arm64 + x86_64, ≈ 86 MB) — builds; no system image installed to boot it.
- ⬜ **Release signing (Android)**: create your own keystore (keep it OUT of the repo, back it up — losing it means you can never update the app):
  `"%USERPROFILE%\.android-toolchain\jdk\bin\keytool" -genkeypair -v -keystore theascent-release.keystore -alias theascent -keyalg RSA -keysize 2048 -validity 10000`
  then set `export/android/release_keystore`, `_user`, `_pass` in Godot's editor settings and run `--export-release "Android Phone"`. For Play Store you'll want an AAB (gradle build — needs `android_source.zip` from the templates).
- ⬜ Windows exe icon/metadata: needs `rcedit` configured in editor settings (`export/windows/rcedit`) — the build works without it, just with Godot's icon.
- ⬜ iOS: needs a Mac + Xcode.

## Quality gates
- ✅ 355 automated checks pass (`docs/TESTING.md`) incl. a full end-to-end playthrough with real scene changes, a fall, quit/Continue, and the TRUTH ending.
- ✅ Two independent code reviews (26 defects found, all fixed with regression tests).
- ✅ Error sweep: every scene on both renderers loads with no errors/warnings (only the harmless test-harness "ObjectDB leaked at exit").
- 🟡 Performance: Medium re-profiled with the real assets (≈ 55–65 fps on the iGPU); High/Ultra/phone renderer still to re-measure (`docs/PERFORMANCE.md`). Auto quality adapts on slow GPUs.
- ✅ Logs: written on all platforms to `user://logs/` (Windows: `%APPDATA%\Godot\app_userdata\The Ascent\logs`); Settings → "Open log folder".
- 🟡 **Human playtest** — difficulty, pacing, scares, puzzle clarity. Nobody has played it start to finish by hand yet.
- 🟡 **Phone test** — fps, gyro axes, vibration, button reach (`docs/MOBILE_BUILD.md`).

## Content & legal
- ✅ Every third-party asset is CC0, MIT or CC-BY with source, author and licence recorded (`docs/ASSET_LICENCES.md`): Poly Haven textures + models (CC0), Microsoft Rocketbox characters (MIT), recorded sound (CC0 + CC-BY 3.0). No third-party trademarks.
- ✅ In-game **Credits** page on the title screen: every CC-BY author with links, the Rocketbox MIT notice, Godot's licence + third-party notices (tested). The ending has a short credit line pointing to it.
- ⬜ Final name (THE ASCENT / STHIR / FLOOR ZERO / UPAR), store description, screenshots, trailer.
- ⬜ Privacy policy (the game collects nothing and has no network code — say so).
- ⬜ Pricing & the free-floors (G–2) + one-time unlock. Payments are NOT implemented (by design in the brief); the save/unlock code is ready to gate floors 3–8 behind an entitlement flag.
- ⬜ Content rating questionnaire (horror themes, no gore).

## Known limitations (ship or fix later)
- Characters are stock Rocketbox avatars (re-tinted), not bespoke designs; no facial animation or lip-sync. Doors, lockers, boards and stairs are still kit-built boxes.
- Phone ring, hum, whispers, gasps and the footsteps-behind-you are still synthesised (no suitably licensed recordings found).
- CC-BY / MIT attributions live in-game under Credits — keep `scripts/systems/credits.gd` in sync with `docs/ASSET_LICENCES.md` when assets change.
- Floor 6's shadow passes through walls (only the mirror room holds it).
- Daily Corridor leaderboard is local only (`scripts/systems/leaderboard.gd` has the integration point).
- Gyroscope axes unverified on hardware.
