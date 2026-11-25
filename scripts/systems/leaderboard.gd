extends RefCounted
## Daily Corridor scores. Offline: best score per date in user://daily.json.
## INTEGRATION POINT: to add an online leaderboard later, implement
## _submit_remote() (HTTPRequest from a Node) and call it from submit().
## No network code ships in the prototype.

const PATH := "user://daily.json"
const REMOTE_URL := ""     # e.g. "https://api.example.com/ascent/daily" — leave empty offline

static func today() -> String:
	return Time.get_date_string_from_system()

## Same anomaly sequence for every player on the same date.
static func seed_for(date: String) -> int:
	return hash("meridian-daily-" + date)

static func _load() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d = JSON.parse_string(FileAccess.open(PATH, FileAccess.READ).get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func best(date: String) -> int:
	return int(_load().get(date, 0))

## Returns true if this is a new best for the date.
static func submit(date: String, score: int) -> bool:
	var d := _load()
	var is_best := score > int(d.get(date, 0))
	if is_best:
		d[date] = score
		var f := FileAccess.open(PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(d))
	# if REMOTE_URL != "": _submit_remote(date, score)   # future backend
	return is_best
