extends RefCounted
## Rules for the sensing-truck scenario. Pure static functions: no nodes, no
## randomness. Numbers all come from data/truck.json (placeholders for now).
## Use it through a preload:  const TruckSim = preload("res://scripts/core/truck_sim.gd")

const EPS: float = 0.0001
const PATH: String = "res://data/truck.json"


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		push_error("Data file not found: " + PATH)
		return {}
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("JSON error in %s: %s" % [PATH, json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = json.data
	return out


static func sensor_by_id(cfg: Dictionary, id: String) -> Dictionary:
	var list: Array = cfg.get("sensors", [])
	for item in list:
		var s: Dictionary = item
		if str(s.get("id", "")) == id:
			return s
	return {}


## Chance (0..1) that at least one chosen sensor sees the obstacle in a condition.
## Every sensor has to miss for the truck to miss, so: 1 - product of miss chances.
static func detect_chance(cfg: Dictionary, selected: Array, condition_id: String) -> float:
	if selected.is_empty():
		return 0.0
	var miss: float = 1.0
	for id in selected:
		var s: Dictionary = sensor_by_id(cfg, str(id))
		var detect: Dictionary = s.get("detect", {})
		miss *= 1.0 - float(detect.get(condition_id, 0.0))
	return 1.0 - miss


## The unselected sensor that would help most in a condition ("" if none helps).
static func best_addition(cfg: Dictionary, selected: Array, condition_id: String) -> String:
	var best_id: String = ""
	var best_gain: float = 0.0
	var base: float = detect_chance(cfg, selected, condition_id)
	var list: Array = cfg.get("sensors", [])
	for item in list:
		var s: Dictionary = item
		var id: String = str(s.get("id", ""))
		if selected.has(id):
			continue
		var with_it: Array = selected.duplicate()
		with_it.append(id)
		var gain: float = detect_chance(cfg, with_it, condition_id) - base
		if gain > best_gain + EPS:
			best_gain = gain
			best_id = id
	return best_id


## Everything the screen shows. selected is an Array of sensor ids.
static func evaluate(cfg: Dictionary, selected: Array) -> Dictionary:
	var limits: Dictionary = cfg.get("limits", {})
	var target: float = float(cfg.get("target_detect_pct", 95.0))
	var mass: float = 0.0
	var power: float = 0.0
	var cost: float = 0.0
	for id in selected:
		var s: Dictionary = sensor_by_id(cfg, str(id))
		mass += float(s.get("mass_kg", 0.0))
		power += float(s.get("power_w", 0.0))
		cost += float(s.get("cost_k", 0.0))
	var mass_ok: bool = mass <= float(limits.get("mass_kg", 0.0)) + EPS
	var power_ok: bool = power <= float(limits.get("power_w", 0.0)) + EPS
	var cost_ok: bool = cost <= float(limits.get("budget_k", 0.0)) + EPS

	var conditions: Array = []
	var causes: Array = []
	var all_detect_ok: bool = true
	var cond_list: Array = cfg.get("conditions", [])
	for item in cond_list:
		var c: Dictionary = item
		var id: String = str(c.get("id", ""))
		var pct: float = detect_chance(cfg, selected, id) * 100.0
		var passed: bool = pct >= target - EPS
		var tip_id: String = ""
		if not passed:
			all_detect_ok = false
			tip_id = best_addition(cfg, selected, id)
			var cause: String = "%s: the truck sees only %.1f%% of obstacles (needs %.0f%%). %s" % [
					str(c.get("name", id)), pct, target, str(c.get("why", ""))]
			if tip_id != "":
				cause += " Adding a %s would help most here." % str(sensor_by_id(cfg, tip_id).get("name", tip_id)).to_lower()
			causes.append(cause)
		conditions.append({"id": id, "name": str(c.get("name", id)), "detect_pct": pct, "passed": passed, "tip_id": tip_id})
	if not mass_ok:
		causes.append("Too heavy: %.1f kg of sensors, but the truck can carry %.1f kg." % [mass, float(limits.get("mass_kg", 0.0))])
	if not power_ok:
		causes.append("Too much power: the sensors draw %.0f W, but only %.0f W is available." % [power, float(limits.get("power_w", 0.0))])
	if not cost_ok:
		causes.append("Over budget: $%.0fk of sensors, but the budget is $%.0fk." % [cost, float(limits.get("budget_k", 0.0))])
	var limits_ok: bool = mass_ok and power_ok and cost_ok
	return {
		"mass_kg": mass, "power_w": power, "cost_k": cost,
		"mass_ok": mass_ok, "power_ok": power_ok, "cost_ok": cost_ok,
		"conditions": conditions, "all_detect_ok": all_detect_ok,
		"passed": all_detect_ok and limits_ok and not selected.is_empty(),
		"causes": causes,
	}
