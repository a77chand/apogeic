## Loads the balance files in data/ and turns every {"value": x, "source": "..."}
## wrapper into a plain number, so the simulation never has to think about sources.
##
## Usage:
##   const GameData = preload("res://scripts/sim/game_data.gd")
##   var data = GameData.load_all()
##   if not data.errors.is_empty(): push_error(str(data.errors))
extends RefCounted

const DATA_DIR := "res://data/"
const FILES := ["modules", "events", "crew", "scenarios", "tutorial"]


## Returns {"modules": {...}, "events": {...}, "crew": {...}, "scenarios": {...},
## "tutorial": {...}, "errors": [strings]}.
static func load_all() -> Dictionary:
	var out := {}
	var errors: Array = []
	for file_name in FILES:
		var path: String = DATA_DIR + file_name + ".json"
		# get_file_as_string returns "" if the file is missing. On the web export the
		# JSON files are only included because export_presets.cfg lists data/*.json.
		var text := FileAccess.get_file_as_string(path)
		if text == "":
			errors.append("Could not read %s" % path)
			continue
		var parsed = JSON.parse_string(text)  # null if the JSON has a syntax error
		if parsed == null:
			errors.append("%s is not valid JSON" % path)
			continue
		check_sources(parsed, file_name, errors)
		out[file_name] = unwrap(parsed)
	out["errors"] = errors
	return out


## Recursively replaces {value, source} wrappers with the bare value.
## Keys starting with "_" (like "_comment") are dropped.
static func unwrap(v):
	if v is Dictionary:
		if v.has("value") and v.has("source"):
			return v["value"]
		var d := {}
		for key in v:
			if str(key).begins_with("_"):
				continue
			d[key] = unwrap(v[key])
		return d
	if v is Array:
		var a := []
		for item in v:
			a.append(unwrap(item))
		return a
	return v


## Rule from docs/DATA_SCHEMA.md: every number needs a "source". This finds bare
## numbers and wrappers with an empty source, and adds a message to `errors`.
static func check_sources(v, path: String, errors: Array) -> void:
	if v is Dictionary:
		if v.has("value") and v.has("source"):
			if str(v["source"]).strip_edges() == "":
				errors.append("%s has an empty source" % path)
			return
		for key in v:
			if not str(key).begins_with("_"):
				check_sources(v[key], path + "." + str(key), errors)
	elif v is Array:
		for i in v.size():
			check_sources(v[i], "%s[%d]" % [path, i], errors)
	elif v is float or v is int:
		errors.append("%s is a bare number; wrap it as {\"value\": %s, \"source\": \"placeholder\"}" % [path, str(v)])
