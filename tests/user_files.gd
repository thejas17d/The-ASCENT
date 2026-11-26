extends RefCounted
## Screenshot / perf / test scripts run the real game, which saves progress,
## settings (Auto quality's learned level) and unlocks. Back the player's files
## up when the script starts and put them back on exit, so a run never touches
## a real save:
##   var _user_files := preload("res://tests/user_files.gd").backup()
##   func _finalize() -> void: preload("res://tests/user_files.gd").restore(_user_files)
## Crash-proof: the backup is also written to user://.test_backup/ first. If a
## run dies before restoring (crash, timeout, kill), the next run finds that
## folder and restores the player's originals before doing anything else.

const FILES := ["user://save.json", "user://settings.json", "user://unlocks.json", "user://daily.json"]
const DIR := "user://.test_backup"
const MISSING := "<missing>"

static func backup() -> Dictionary:
	var out := {}
	if DirAccess.dir_exists_absolute(DIR):
		# a previous run never restored: its backup holds the real originals
		for p in FILES:
			var bp: String = DIR + "/" + str(p).get_file()
			if FileAccess.file_exists(bp):
				var txt := FileAccess.get_file_as_string(bp)
				out[p] = null if txt == MISSING else txt
		_write(out)
		return out
	DirAccess.make_dir_recursive_absolute(DIR)
	for p in FILES:
		out[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
		var f := FileAccess.open(DIR + "/" + str(p).get_file(), FileAccess.WRITE)
		if f:
			f.store_string(MISSING if out[p] == null else out[p])
			f.close()
	return out

static func restore(bak: Dictionary) -> void:
	_write(bak)
	for p in FILES:
		var bp: String = DIR + "/" + str(p).get_file()
		if FileAccess.file_exists(bp):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bp))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))

static func _write(bak: Dictionary) -> void:
	for p in bak:
		if bak[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			if f:
				f.store_string(bak[p])
				f.close()
