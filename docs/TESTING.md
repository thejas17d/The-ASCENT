# Testing
`godot --headless --path . -s res://tests/test_floor2.gd` → 21 checks (data load, 20 doors, every anomaly changes the scene, judgement, Room 213, violations). Last run: 21/21 pass.
`godot --path . -s res://tests/shot.gd -- <anomaly_id>` saves a screenshot to user://shot.png.
Not yet tested: real playtest feel, touch devices, performance on Android.
