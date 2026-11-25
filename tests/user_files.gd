extends RefCounted
## Screenshot / perf scripts run the real game, which saves progress, settings
## (Auto quality's learned level) and unlocks. Back the player's files up when
## the script starts and put them back on exit, so a capture run never touches
## a real save:
##   var _user_files := preload("res://tests/user_files.gd").backup()
##   func _finalize() -> void: preload("res://tests/user_files.gd").restore(_user_files)

const FILES := ["user://save.json", "user://settings.json", "user://unlocks.json", "user://daily.json"]

static func backup() -> Dictionary:
	var out := {}
	for p in FILES:
		out[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	return out

static func restore(bak: Dictionary) -> void:
	for p in bak:
		if bak[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(bak[p])
				f.close()
