# Testing
`godot --headless --path . -s res://tests/test_floor2.gd` → 50 checks: corridor/anomalies/judgement/Room 213 plus save-load, battery, chalk, diya safe zone, dread rise/fall/breakdown, phone layer, hiding, breath/gasp, director gating/cooldowns, every event. Backs up and restores your real save. Last run: 50/50 pass.
`godot --path . -s res://tests/shot.gd -- <anomaly_id>` saves a screenshot to user://shot.png.
Not yet tested: real playtest feel, touch devices, performance on Android.
