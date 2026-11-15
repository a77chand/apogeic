extends RefCounted
## Rules for the sensing-truck scenario (an autonomous digging robot at the Moon's south pole). Pure static functions: no nodes, no
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
		miss *= 1.0 - _boosted(cfg, selected, str(id), condition_id, float(detect.get(condition_id, 0.0)))
	return 1.0 - miss


## A sensor's chance can be raised by another fitted part: headlights let the cameras see in
## shadow and darkness (their "boosts" in truck.json). The higher value wins.
static func _boosted(cfg: Dictionary, selected: Array, sensor_id: String, condition_id: String, value: float) -> float:
	var out: float = value
	for other in selected:
		var o: Dictionary = sensor_by_id(cfg, str(other))
		var boosts: Dictionary = o.get("boosts", {})
		if boosts.has(sensor_id):
			out = maxf(out, float((boosts[sensor_id] as Dictionary).get(condition_id, 0.0)))
	return out


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


## How well the chosen sensors cover a condition, as a word: the detection numbers are
## mostly illustrative, so the screens show this ranking instead of a precise-looking %.
## "Covered" = meets the target, "Weak" = within 15 points of it, "Blind" = below that.
static func coverage_word(cfg: Dictionary, pct: float) -> String:
	var target: float = float(cfg.get("target_detect_pct", 95.0))
	if pct >= target - EPS:
		return "Covered"
	if pct >= target - 15.0:
		return "Weak"
	return "Blind"


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
			var cause: String = "%s: %s. %s" % [
					str(c.get("name", id)), "weak coverage, it would miss some rocks" if coverage_word(cfg, pct) == "Weak" else "blind, it would miss most rocks", str(c.get("why", ""))]
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


# ---------------------------------------------------------------- route challenges
## A route is a grid of letters: "." open ground, "#" a ridge (cannot be crossed, casts a
## shadow), "C" a crater floor that never sees sunlight, "D" digging dust, "/" a slope,
## "S" the start and "G" the dig site. The Sun is low; sun_az is where it is (180 = from
## the left), and it moves sun_step_deg every step, so the shadows sweep round.

static func route_cell(route: Dictionary, c: Vector2i) -> String:
	var grid: Array = route.get("grid", [])
	if c.y < 0 or c.y >= grid.size():
		return "#"
	var row: String = str(grid[c.y])
	if c.x < 0 or c.x >= row.length():
		return "#"
	return row[c.x]


static func route_find(route: Dictionary, letter: String) -> Vector2i:
	var grid: Array = route.get("grid", [])
	for y in range(grid.size()):
		var x: int = str(grid[y]).find(letter)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## The squares in shadow at step t: behind every ridge square, away from the Sun.
static func route_shadows(cfg: Dictionary, route: Dictionary, t: int) -> Dictionary:
	var az: float = deg_to_rad(float(route.get("sun_az", 180.0)) + float(route.get("sun_step_deg", 0.0)) * float(t))
	var dir: Vector2 = Vector2(-cos(az), sin(az))
	var length: int = int((cfg.get("route_energy", {}) as Dictionary).get("shadow_length", 5))
	var out: Dictionary = {}
	var grid: Array = route.get("grid", [])
	for y in range(grid.size()):
		var row: String = str(grid[y])
		for x in range(row.length()):
			if row[x] != "#":
				continue
			for k in range(1, length + 1):
				# round half away from zero, the same as the level check in tools
				var fx: float = float(x) + dir.x * float(k)
				var fy: float = float(y) + dir.y * float(k)
				var p: Vector2i = Vector2i(int(roundf(fx)), int(roundf(fy)))
				if route_cell(route, p) != "#":
					out[p] = true
	return out


static func route_condition(route: Dictionary, c: Vector2i, shadows: Dictionary) -> String:
	var letter: String = route_cell(route, c)
	if letter == "C":
		return "dark"
	if letter == "D":
		return "dust"
	if shadows.has(c):
		return "shadow"
	if letter == "/":
		return "slope"
	return "clear"


## Plays a path (start first; a repeated square is a wait). Returns every step with its
## condition, whether the kit sees rocks there, and the battery; plus where it failed.
static func route_eval(cfg: Dictionary, route: Dictionary, path: Array) -> Dictionary:
	var energy: Dictionary = cfg.get("route_energy", {})
	var target: float = float(cfg.get("target_detect_pct", 95.0))
	var kit: Array = route.get("kit", [])
	var battery: float = float(route.get("battery", 10))
	var cap: float = float(route.get("capacity", 30))
	var steps: Array = []
	var fail: String = ""
	for i in range(1, path.size()):
		var prev: Vector2i = path[i - 1]
		var c: Vector2i = path[i]
		var sh: Dictionary = route_shadows(cfg, route, i)
		var cond: String = route_condition(route, c, sh)
		var pct: float = detect_chance(cfg, kit, cond) * 100.0
		var wait: bool = c == prev
		var gain: float = 0.0
		if wait:
			gain = float(energy.get("wait_clear", 4)) if cond == "clear" else float(energy.get("wait_other", -2))
		else:
			gain = float(energy.get(cond, 0))
		battery = minf(cap, battery + gain)
		var safe: bool = pct >= target - EPS
		steps.append({"cell": c, "cond": cond, "pct": pct, "safe": safe, "battery": battery, "wait": wait})
		if fail == "":
			if not safe:
				fail = "The rover drove into %s, where its sensors are %s, and hit a rock." % [_cond_words(cond), coverage_word(cfg, pct).to_lower()]
			elif battery <= 0.0:
				fail = "The battery ran flat in %s." % _cond_words(cond)
	var reached: bool = not path.is_empty() and path[path.size() - 1] == route_find(route, "G")
	return {"steps": steps, "fail": fail, "reached": reached, "ok": reached and fail == "", "battery": battery}


static func _cond_words(cond: String) -> String:
	return {"clear": "sunlight", "shadow": "a shadow", "dark": "a crater that never sees sunlight", "dust": "digging dust", "slope": "a slope"}.get(cond, cond)
