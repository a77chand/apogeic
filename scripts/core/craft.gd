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


static func _clean(x: float) -> String:
	return str(int(x)) if absf(x - roundf(x)) < 0.05 else "%.1f" % x


## The level for craft `id`. Unknown ids give an unchanged copy. A level can set
## "mass_limit_factor" (below 1 = a tighter rocket slot) to make its own limit.
static func apply(level: Dictionary, cfg: Dictionary, id: String) -> Dictionary:
	var out: Dictionary = level.duplicate(true)
	var craft: Dictionary = by_id(cfg, id)
	if craft.is_empty():
		return out
	var game: Dictionary = craft.get("game", {})
	var base_game: Dictionary = by_id(cfg, BASE_ID).get("game", {})
	var base_limit: float = float(base_game.get("mass_limit_kg", 1.0))
	var limit: float = float(game.get("mass_limit_kg", base_limit)) * float(level.get("mass_limit_factor", 1.0))
	# a mission can set its own numbers per size (Earth Imager uses the team's values sheet):
	# the mass limit, and the most power the craft can make (panels are capped at it)
	var own: Dictionary = (level.get("craft_values", {}) as Dictionary).get(id, {})
	if not own.is_empty():
		limit = float(own.get("mass_kg", limit))
		if own.has("power_w"):
			out["power_cap_w"] = float(own["power_w"])
	var scale: float = float(game.get("mass_limit_kg", base_limit)) / maxf(0.001, base_limit)  # the bus structure grows and shrinks with the craft
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
		elif str(r.get("kind", "")) == "delivered_min" and absf(scale - 1.0) > 0.001:
			# a smaller craft makes and sends proportionally less data
			r["target"] = snappedf(float(r.get("target", 0.0)) * scale, 0.1)
			r["text"] = str(r.get("text", "")).split(" at least ")[0] + " at least %s MB" % _clean(float(r["target"])) + str(r.get("text", "")).split(" MB", 1)[1]
	if absf(scale - 1.0) > 0.001:
		var ops: Dictionary = out.get("ops", {})
		ops["goal_mb"] = snappedf(float(ops.get("goal_mb", 0.0)) * scale, 0.1)
		ops["storage_mb"] = snappedf(float(ops.get("storage_mb", 0.0)) * scale, 0.1)
		bus["power_use_w"] = float(bus.get("power_use_w", 0.0)) * scale
	_apply_own_values(out, level, own)
	return out


## A mission's own numbers for this size (data/level1.json "craft_values"), applied last:
##   bus_power_w  what the bare satellite uses
##   budget_k     the money for this size
##   data_kbps    how fast this size can send, compared with the 3U's: the weekly data goal
##                scales with it (a 1U radio is far slower, so it is asked for less)
static func _apply_own_values(out: Dictionary, level: Dictionary, own: Dictionary) -> void:
	if own.is_empty():
		return
	if own.has("bus_power_w"):
		(out["bus"] as Dictionary)["power_use_w"] = float(own["bus_power_w"])
	if own.has("budget_k"):
		(out["limits"] as Dictionary)["budget_k"] = float(own["budget_k"])
	var base_kbps: float = float(((level.get("craft_values", {}) as Dictionary).get(BASE_ID, {}) as Dictionary).get("data_kbps", 0.0))
	if own.has("data_kbps") and base_kbps > 0.0:
		var k: float = float(own["data_kbps"]) / base_kbps
		var base_ops: Dictionary = level.get("ops", {})
		(out["ops"] as Dictionary)["goal_mb"] = snappedf(float(base_ops.get("goal_mb", 0.0)) * k, 0.1)
		var base_reqs: Array = level.get("requirements", [])
		var reqs: Array = out.get("requirements", [])
		for i in range(reqs.size()):
			var r: Dictionary = reqs[i]
			if str(r.get("kind", "")) == "delivered_min":
				var t: float = snappedf(float((base_reqs[i] as Dictionary).get("target", 0.0)) * k, 0.1)
				r["target"] = t
				r["text"] = "Deliver at least %s MB of %s per week" % [_clean(t), str(level.get("data_noun", "data"))]


## How much bigger or smaller than the 3U base this craft is (its mass limit over the base
## limit). Parts, power and data scale with it, so every size plays like the same puzzle:
## a 1U needs tiny parts, a 6U can carry bigger ones.
static func scale_of(cfg: Dictionary, id: String) -> float:
	var game: Dictionary = by_id(cfg, id).get("game", {})
	var base: Dictionary = by_id(cfg, BASE_ID).get("game", {})
	return float(game.get("mass_limit_kg", 1.0)) / maxf(0.001, float(base.get("mass_limit_kg", 1.0)))


## A copy of the parts with mass, power, battery and data scaled to a craft size.
static func scale_parts(parts: Dictionary, s: float) -> Dictionary:
	var out: Dictionary = parts.duplicate(true)
	for key in out.keys():
		var p: Dictionary = out[key]
		for field in ["mass_kg", "power_gen_w", "power_use_w", "battery_wh", "make_mb_wk", "send_mb_wk"]:
			if p.has(field):
				p[field] = float(p[field]) * s
	return out
