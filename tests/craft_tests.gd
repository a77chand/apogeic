extends SceneTree
## Checks the craft size rules. Run from the project folder:
##   godot --headless --path . --script res://tests/craft_tests.gd

const Craft = preload("res://scripts/core/craft.gd")
const Data = preload("res://scripts/core/data.gd")
const Sim = preload("res://scripts/core/sim.gd")

var fails: Array = []


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


func _initialize() -> void:
	var cfg: Dictionary = Craft.load_config()
	var base: Dictionary = Data.load_level1()
	check(Craft.ids(cfg) == ["1u", "3u", "6u"], "three sizes load")
	# 3U must be exactly the existing level, so nothing else moves
	var u3: Dictionary = Craft.apply(base, cfg, "3u")
	check(JSON.stringify(u3) == JSON.stringify(base), "3U is identical to level1.json")
	# apply() never changes the level it is given
	var before: String = JSON.stringify(base)
	var u6: Dictionary = Craft.apply(base, cfg, "6u")
	check(JSON.stringify(base) == before, "apply() leaves the base level untouched")
	check(float(u6["limits"]["mass_kg"]) == 8.0 and float(u6["launch"]["cost_k"]) == 395.0, "6U: 8 kg limit, $395k launch")
	check(absf(float(u6["bus"]["mass_kg"]) - 2.6) < 0.0001, "6U bus is twice as heavy (2.6 kg)")
	check(float(u6["bus"]["cost_k"]) == float(base["bus"]["cost_k"]), "bus cost is not changed")
	var r1: Dictionary = {}
	for item in u6["requirements"]:
		if str(item["id"]) == "R1":
			r1 = item
	check(float(r1["target"]) == 8.0 and str(r1["text"]).contains("8.0 kg"), "6U requirement R1 says 8.0 kg")
	var u1: Dictionary = Craft.apply(base, cfg, "1u")
	check(float(u1["limits"]["mass_kg"]) == 1.33 and float(u1["launch"]["cost_k"]) == 65.0, "1U: 1.33 kg limit, $65k launch")
	# every launch cost is inside the sourced range
	for id in ["1u", "3u", "6u"]:
		var c: Dictionary = Craft.by_id(cfg, id)
		var cost: float = float(c["game"]["launch_cost_k"])
		check(cost >= float(c["launch_cost_k"]["min"]) and cost <= float(c["launch_cost_k"]["max"]), id + " launch cost is inside its range")
	# the same camera design: too heavy for 1U, fine for 3U and 6U
	var parts: Dictionary = Data.load_parts()
	var design: Dictionary = {"solar": "solar_small", "battery": "battery_std", "instrument": "camera_std", "radio": "radio_sband", "extra_a": "", "extra_b": ""}
	var sched: Dictionary = Sim.new_schedule()
	var ok1: bool = bool(Sim.check_requirements(u1, Sim.evaluate_design(u1, parts, design, sched))[0]["passed"])
	var ok3: bool = bool(Sim.check_requirements(u3, Sim.evaluate_design(u3, parts, design, sched))[0]["passed"])
	var ok6: bool = bool(Sim.check_requirements(u6, Sim.evaluate_design(u6, parts, design, sched))[0]["passed"])
	check(not ok1 and ok3 and ok6, "mass check: 1U fails, 3U and 6U pass (got %s %s %s)" % [ok1, ok3, ok6])
	var cost3: float = float(Sim.evaluate_design(u3, parts, design, sched)["total_cost_k"])
	var cost6: float = float(Sim.evaluate_design(u6, parts, design, sched)["total_cost_k"])
	check(cost6 > cost3, "6U costs more than 3U for the same parts (%s vs %s)" % [cost6, cost3])
	# 6U launch + parts leave less than the 10% reserve: the choice has a real price
	var res6: float = float(Sim.evaluate_design(u6, parts, design, sched)["reserve_pct"])
	check(res6 < 10.0, "6U with the reference design misses the 10%% reserve (%.1f%%)" % res6)
	if fails.is_empty():
		print("CRAFT TESTS PASSED")
		quit(0)
	else:
		for f in fails:
			printerr("FAILED: ", f)
		quit(1)
