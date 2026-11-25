# Replayability (Phase 6)

| Feature | How to reach it | What it does | Where |
|---|---|---|---|
| **Night Shift** | Title → *New Game+ — Night Shift* (after any ending) | Every light ×0.6, fear builds ×1.3, Supervisor +15% speed / +20% hearing / +10% sight, Floor 2 needs 10 in a row and has more anomalies. **Every rule board carries one extra rule that is a lie** — the phone camera shows it struck through in red (3D label on render layer 2 + panel note). | `GameState.night()`, `light_scale()`, `FloorBase.inject_night_rule()`, `night_rule` in `data/floor_rules/*.json` |
| **New Game+** | same button | Starts the Night Shift with +2 batteries and +2 diyas; endings count the loop ("the second building…"). | `GameState.NG_PLUS_BONUS`, `unlocks.loops` |
| **Memories** | Title → *Memories (found / total)* | Journal of every note, photo, report, letter, ID card, voice note and the Floor 9 reveal you have **ever** found, across runs. | `scripts/systems/memories.gd`, `unlocks.memories` in `user://unlocks.json` |
| **Voice notes** | 3 cassettes (Floors 3, 5, 7) | Press **V**: Mummy's voice, Dread −35 over 6 s. Limited — each is used up. | `FloorBase.play_voice_note()`, `data/story/voice_notes.json` |
| **Daily Corridor** | Title → *Daily Corridor (best today)* | Floor 2's anomaly loop, endless, seeded by today's date — the same sequence for every player today. One mistake ends the run; best score per date saved locally. Never touches the story save. | `scripts/systems/leaderboard.gd` (offline; `REMOTE_URL` + `_submit_remote()` is the backend integration point) |
| **Floor 9 — The Blueprint** | Title → *Floor 9* (after a run with **zero falls**) | A glowing blueprint of the tower in the void. Touch all nine storeys of the model to remember each floor; the scratched-out man gets a name (R. K. Mehra, owner) — he built another building. Sequel hook for the ESCAPE ending. | `scripts/floors/floor_09.gd` |

Unlocks live in `user://unlocks.json` and survive finished runs (the run save is deleted at an ending).
