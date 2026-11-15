extends RefCounted
## Loads the JSON data files. Pure static functions, no scene access.
## Use it through a preload:  const Data = preload("res://scripts/core/data.gd")

const PARTS_PATH: String = "res://data/parts.json"
const LEVEL1_PATH: String = "res://data/level1.json"
## The missions in the order they unlock. Each is data/<id>.json, each based on a real
## spaceflight (its "based_on" block). Levels 4-20 are built by tools/make_missions.py.
const MISSIONS: Array = ["level1", "level4", "level5", "level6", "level7", "level8", "level9", "level2", "level10", "level11",
		"level12", "level13", "level14", "level3", "level15", "level16", "level17", "level18", "level19", "level20"]
const EVENTS_PATH: String = "res://data/events.json"
const PUZZLES_PATH: String = "res://data/puzzles.json"


## Returns the parsed JSON (a Dictionary or Array), or null if the file is missing or broken.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: " + path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open data file: " + path)
		return null
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("JSON error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Returns a Dictionary with a guaranteed type, even when the file failed to load.
static func load_dict(path: String) -> Dictionary:
	var data: Variant = load_json(path)
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


## Returns parts keyed by id:  { "camera_std": {...}, ... }
static func load_parts() -> Dictionary:
	var out: Dictionary = {}
	var root: Dictionary = load_dict(PARTS_PATH)
	var list: Array = root.get("parts", [])
	for item in list:
		var part: Dictionary = item
		out[str(part.get("id", ""))] = part
	return out


static func load_level1() -> Dictionary:
	return load_dict(LEVEL1_PATH)


## One mission by id ("level1", "level2" ...). An unknown id gives an empty Dictionary.
static func load_level(id: String) -> Dictionary:
	if not MISSIONS.has(id):
		return {}
	return load_dict("res://data/%s.json" % id)


static func load_puzzles() -> Dictionary:
	return load_dict(PUZZLES_PATH)


## Returns the list of event Dictionaries.
static func load_events() -> Array:
	var root: Dictionary = load_dict(EVENTS_PATH)
	var list: Array = root.get("events", [])
	return list


## "ops:4", "test_lab:0": the key for a moment in the mission.
static func slot_key(when: String, week: int) -> String:
	return "%s:%d" % [when, week]


## Every moment that has events, mapped to the ids of the events that could fire there.
## Events with a "mission" id belong to that mission only; pass mission_id to leave out
## every other mission's own events.
static func event_slots(events: Array, mission_id: String = "") -> Dictionary:
	var out: Dictionary = {}
	for item in events:
		var ev: Dictionary = item
		var owner: String = str(ev.get("mission", ""))
		if owner != "" and owner != mission_id:
			continue
		var key: String = slot_key(str(ev.get("when", "")), int(ev.get("week", 0)))
		if not out.has(key):
			out[key] = []
		var ids: Array = out[key]
		ids.append(str(ev.get("id", "")))
	return out


## Returns the event that fires at a given moment (an empty list if there is none).
## when is "test_lab" or "ops". When several events share the moment, picks[key] says which
## one was chosen for this attempt. Without a pick the first one listed is used, so the
## self-test always sees the same events.
static func events_for(events: Array, when: String, week: int, picks: Dictionary = {}) -> Array:
	var candidates: Array = []
	for item in events:
		var ev: Dictionary = item
		if str(ev.get("when", "")) == when and int(ev.get("week", 0)) == week:
			if str(ev.get("mission", "")) != "" and str(picks.get(slot_key(when, week), "")) != str(ev.get("id", "")):
				continue   # a mission's own event only fires when it was picked for that mission
			candidates.append(ev)
	if candidates.size() <= 1:
		return candidates
	var wanted: String = str(picks.get(slot_key(when, week), ""))
	for item in candidates:
		var ev: Dictionary = item
		if str(ev.get("id", "")) == wanted:
			return [ev]
	return [candidates[0]]
