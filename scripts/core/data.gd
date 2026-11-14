extends RefCounted
## Loads the JSON data files. Pure static functions, no scene access.
## Use it through a preload:  const Data = preload("res://scripts/core/data.gd")

const PARTS_PATH: String = "res://data/parts.json"
const LEVEL1_PATH: String = "res://data/level1.json"
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


static func load_puzzles() -> Dictionary:
	return load_dict(PUZZLES_PATH)


## Returns the list of event Dictionaries.
static func load_events() -> Array:
	var root: Dictionary = load_dict(EVENTS_PATH)
	var list: Array = root.get("events", [])
	return list


## Returns the events that fire at a given moment. when is "test_lab" or "ops".
static func events_for(events: Array, when: String, week: int) -> Array:
	var out: Array = []
	for item in events:
		var ev: Dictionary = item
		if str(ev.get("when", "")) == when and int(ev.get("week", 0)) == week:
			out.append(ev)
	return out
