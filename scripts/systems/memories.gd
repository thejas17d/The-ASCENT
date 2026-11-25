extends RefCounted
## Registry of every collectible memory (notes, photos, report, letter, ID
## cards, voice notes). The title-screen journal lists them; found ones are
## GameState.unlocks.memories (kept across runs).

const NOTE_FILES := ["floor_00", "floor_01", "floor_02", "floor_03", "floor_04", "floor_05", "floor_06", "floor_07", "floor_08"]
const SPECIAL := [
	{"id": "h_photo_beach", "floor": 4, "title": "Photograph — Juhu beach",
	 "text": "Mummy laughing, Papa squinting into the sun, you on his shoulders.\nOn the back: \"Sunday. He promised more Sundays.\""},
	{"id": "h_photo_site", "floor": 4, "title": "Photograph — the site, May '98",
	 "text": "Papa in a yellow helmet beside a tall man in a long coat. The tall man's face is scratched out so hard the paper tore."},
	{"id": "h_photo_birthday", "floor": 4, "title": "Photograph — nine candles",
	 "text": "You blowing out nine candles. Papa's chair empty in the background.\n\"Arjun — 9 today! 14 · 6 · 98\""},
	{"id": "h_letter", "floor": 4, "title": "Papa's letter",
	 "text": "\"On the night of your birthday I signed a report that said this building was safe. It was not… Six men did not go home at all.\" — Papa"},
	{"id": "r_report", "floor": 3, "title": "Inspection report, 11 June 1998",
	 "text": "HALT ALL SLAB POURS ABOVE FLOOR 4 — struck through in red ink.\nNO DEFECTS FOUND. Signed P. Desai. Countersigned (illegible), Site Supervisor."},
	{"id": "id_ramesh", "floor": 1, "title": "ID card — Ramesh Patil", "text": "Site worker, Meridian Constructions. Kept a steel tiffin in his locker."},
	{"id": "id_suresh", "floor": 1, "title": "ID card — Suresh Yadav", "text": "Site worker. His spectacles case was the only thing on his desk."},
	{"id": "id_abdul", "floor": 1, "title": "ID card — Abdul Karim", "text": "Site worker. Folded his prayer cap the same way every shift."},
	{"id": "id_joseph", "floor": 1, "title": "ID card — Joseph D'Souza", "text": "Site worker. Played Konkani songs on a cassette during the night pours."},
	{"id": "id_mahadev", "floor": 1, "title": "ID card — Mahadev Gaikwad", "text": "Site worker. Never wrote his name on anything. His daughter's photo didn't need one."},
	{"id": "id_babu", "floor": 1, "title": "ID card — Babu Rao", "text": "Site worker and union man. Asked for the pour to be stopped. Twice."},
	{"id": "voice_1", "floor": 3, "title": "Voice note — counting", "text": "\"If you're scared, count with me. Ek. Do. Teen.\""},
	{"id": "voice_2", "floor": 5, "title": "Voice note — dinner", "text": "\"Your Papa is late again. So it's you and me for dinner. Good.\""},
	{"id": "voice_3", "floor": 7, "title": "Voice note — put it down", "text": "\"Whatever he did, it isn't yours to carry. Put it down and come home.\""},
	{"id": "f9_owner", "floor": 9, "title": "The Supervisor's name", "text": "R. K. MEHRA — Owner, Meridian Constructions. Lives on the top floor of Sunrise Apartments, which he finished in 2003."},
]
static var _all: Array = []

static func all() -> Array:
	if not _all.is_empty():
		return _all
	for f in NOTE_FILES:
		var p := "res://data/notes/%s.json" % f
		if not FileAccess.file_exists(p):
			continue
		var floor_n := int(f.trim_prefix("floor_"))
		for n in JSON.parse_string(FileAccess.open(p, FileAccess.READ).get_as_text()):
			_all.append({"id": n.id, "floor": floor_n, "title": n.title, "text": n.text})
	_all.append_array(SPECIAL)
	_all.sort_custom(func(a, b): return a.floor < b.floor)
	return _all

static func found() -> Array:
	var mem: Array = GameState.unlocks.get("memories", [])
	return all().filter(func(m): return mem.has(m.id))
