extends RefCounted
## Craft size (1U / 3U / 6U) for the main mission. Pure static functions.
## apply() returns a COPY of the level with the mass limit, bus and launch cost for the
## chosen size. 3U returns exactly the numbers in level1.json, so nothing else changes.

const PATH: String = "res://data/craft.json"
const BASE_ID: String = "3u"


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = json.data
	return out


static func by_id(cfg: Dictionary, id: String) -> Dictionary:
	var list: Array = cfg.get("craft", [])
	for item in list:
		var c: Dictionary = item
		if str(c.get("id", "")) == id:
			return c
	return {}


static func ids(cfg: Dictionary) -> Array:
	var out: Array = []
	var list: Array = cfg.get("craft", [])
	for item in list:
		var c: Dictionary = item
		out.append(str(c.get("id", "")))
	return out


## The level for craft `id`. Unknown ids give an unchanged copy.
static func apply(level: Dictionary, cfg: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = level.duplicate(true)
	var craft: Dictionary = by_id(cfg, id)
	if craft.is_empty():
		return out
	var game: Dictionary = craft.get("game", {})
	var base_game: Dictionary = by_id(cfg, BASE_ID).get("game", {})
	var base_limit: float = float(base_game.get("mass_limit_kg", 1.0))
	var limit: float = float(game.get("mass_limit_kg", base_limit))
	var scale: float = limit / maxf(0.001, base_limit)  # the bus structure grows and shrinks with the craft
	var limits: Dictionary = out["limits"]
	limits["mass_kg"] = limit
	var bus: Dictionary = out["bus"]
	bus["name"] = "%s bus" % str(craft.get("name", id))
	bus["mass_kg"] = float(bus.get("mass_kg", 0.0)) * scale
	var launch: Dictionary = out["launch"]
	if not bool(launch.get("keep_cost", false)):   # a mission with its own rocket keeps its own price
		launch["cost_k"] = float(game.get("launch_cost_k", launch.get("cost_k", 0.0)))
	var reqs: Array = out.get("requirements", [])
	for item in reqs:
		var r: Dictionary = item
		if str(r.get("kind", "")) == "mass_max":
			r["target"] = limit
			r["text"] = "Total mass at most %.2f kg" % limit if limit < 2.0 else "Total mass at most %.1f kg" % limit
	return out
