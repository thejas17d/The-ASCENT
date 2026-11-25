# Release checklist — v0.8.0

Legend: ✅ done & verified · 🟡 done, needs a human/device check · ⬜ not done (needs you)

## Build
- ✅ Version 0.8.0 (project + Android versionCode 2 + Windows file version)
- ✅ Windows build: `build_windows.cmd` → `build/windows/TheAscent.exe` + `TheAscent.pck` (≈ 255 MB). Smoke-tested: launches, 400 frames, exit 0, no errors in log.
- ✅ Android phone APK: `build_android.cmd` → `build/TheAscent-phone.apk` (arm64, ≈ 59 MB, debug-signed) + installs via adb.
- 🟡 Android emulator APK (`Android` preset, arm64 + x86_64, ≈ 86 MB) — builds; no system image installed to boot it.
- ⬜ **Release signing (Android)**: create your own keystore (keep it OUT of the repo, back it up — losing it means you can never update the app):
  `"%USERPROFILE%\.android-toolchain\jdk\bin\keytool" -genkeypair -v -keystore theascent-release.keystore -alias theascent -keyalg RSA -keysize 2048 -validity 10000`
  then set `export/android/release_keystore`, `_user`, `_pass` in Godot's editor settings and run `--export-release "Android Phone"`. For Play Store you'll want an AAB (gradle build — needs `android_source.zip` from the templates).
- ⬜ Windows exe icon/metadata: needs `rcedit` configured in editor settings (`export/windows/rcedit`) — the build works without it, just with Godot's icon.
- ⬜ iOS: needs a Mac + Xcode.

## Quality gates
- ✅ 279 automated checks pass (`docs/TESTING.md`) incl. a full end-to-end playthrough with real scene changes, a fall, quit/Continue, and the TRUTH ending.
- ✅ Two independent code reviews (26 defects found, all fixed with regression tests).
- ✅ Error sweep: every scene on both renderers loads with no errors/warnings (only the harmless test-harness "ObjectDB leaked at exit").
- ✅ Performance profiled per floor and preset (`docs/PERFORMANCE.md`); Auto quality adapts on slow GPUs.
- ✅ Logs: written on all platforms to `user://logs/` (Windows: `%APPDATA%\Godot\app_userdata\The Ascent\logs`); Settings → "Open log folder".
- 🟡 **Human playtest** — difficulty, pacing, scares, puzzle clarity. Nobody has played it start to finish by hand yet.
- 🟡 **Phone test** — fps, gyro axes, vibration, button reach (`docs/MOBILE_BUILD.md`).

## Content & legal
- ✅ All textures CC0 (Poly Haven), all audio synthesised in code, all geometry built in code (`docs/ASSET_LICENCES.md`). No third-party trademarks.
- ✅ Credits line in the ending.
- ⬜ Final name (THE ASCENT / STHIR / FLOOR ZERO / UPAR), store description, screenshots, trailer.
- ⬜ Privacy policy (the game collects nothing and has no network code — say so).
- ⬜ Pricing & the free-floors (G–2) + one-time unlock. Payments are NOT implemented (by design in the brief); the save/unlock code is ready to gate floors 3–8 behind an entitlement flag.
- ⬜ Content rating questionnaire (horror themes, no gore).

## Known limitations (ship or fix later)
- Characters (Supervisor, mother, workers, Papa) are primitive figures; levels are kit-built boxes with photographic textures.
- Floor 6's shadow passes through walls (only the mirror room holds it).
- Daily Corridor leaderboard is local only (`scripts/systems/leaderboard.gd` has the integration point).
- Gyroscope axes unverified on hardware.
