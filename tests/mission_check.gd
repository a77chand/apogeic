## Checks every mission, for every craft size it offers:
##   1. some set of the parts offered in its tray earns 3 stars (events ignored), and
##   2. no two missions share the same cheapest 3-star design at their main size (3U where offered),
##      so each mission is its own puzzle.
## Prints each mission's best design. Slow (tries every combination).
##   godot --headless --path . -s tests/mission_check.gd
extends SceneTree
const Sim = preload("res://scripts/core/sim.gd")
const Data = preload("res://scripts/core/data.gd")
const Craft = preload("res://scripts/core/craft.gd")


func designs() -> Array:
	var out: Array = []
	var ex: Array = ["", "antenna_big", "ground2", "shielding"]
	for s in ["", "solar_small", "solar_large"]:
		for b in ["", "battery_small", "battery_std"]:
			for i in ["camera_std", "spectrometer"]:
				for r in ["radio_uhf", "radio_sband"]:
					for a in range(ex.size()):
						for c in range(a, ex.size()):
							if a == c and a != 0:
								continue
							out.append({"solar": s, "battery": b, "instrument": i, "radio": r, "extra_a": ex[a], "extra_b": ex[c] if c != a else ""})
	return out


## Stars for a design flown through the real rules with no events; -1 if it cannot launch.
func stars(level: Dictionary, parts: Dictionary, d: Dictionary) -> Dictionary:
	var sched: Dictionary = Sim.new_schedule()
	sched["day"] = 41
	var ev: Dictionary = Sim.evaluate_design(level, parts, d, sched)
	var results: Array = Sim.check_requirements(level, ev)
	if not bool(Sim.can_launch(ev, results)["ok"]):
		return {"stars": -1, "cost": 0.0}
	if not bool(Sim.launch_outcome(level, results, ev).get("reached_orbit", true)):
		return {"stars": -1, "cost": 0.0}
	var st: Dictionary = Sim.new_ops_state(level, ev, results)
	var guard: int = 0
	while not bool(st["ended"]) and guard < 100:
		guard += 1
		Sim.ops_week(level, ev, st, {})
	return {"stars": int(Sim.score_mission(level, st, results)["stars"]), "cost": float(ev.get("total_cost_k", 0.0))}


func _initialize() -> void:
	var parts: Dictionary = Data.load_parts()
	var cfg: Dictionary = Craft.load_config()
	var all: Array = designs()
	var problems: Array = []
	var best_designs: Dictionary = {}   # design key -> mission id
	for id in Data.MISSIONS:
		var base: Dictionary = Data.load_level(str(id))
		var sizes: Array = [] if str(base.get("craft_kind", "cubesat")) == "satellite" else base.get("craft_sizes", ["3u"])
		if sizes.is_empty():
			sizes = ["3u"]
		var offered: Array = base.get("parts_offered", [])
		for size in sizes:
			var level: Dictionary = Craft.apply(base, cfg, str(size))
			var scaled: Dictionary = Craft.scale_parts(parts, Craft.scale_of(cfg, str(size)))
			var best_cost: float = 1e12
			var best_key: String = ""
			for d in all:
				var ok: bool = true
				for k in d.keys():
					if str(d[k]) != "" and not offered.is_empty() and not offered.has(str(d[k])):
						ok = false
				if not ok:
					continue
				var f: Dictionary = stars(level, scaled, d)
				if int(f["stars"]) >= 3 and float(f["cost"]) < best_cost:
					best_cost = float(f["cost"])
					var names: Array = []
					for k in ["solar", "battery", "instrument", "radio", "extra_a", "extra_b"]:
						if str(d[k]) != "":
							names.append(str(d[k]))
					best_key = " + ".join(PackedStringArray(names))
			print("%-8s %-3s %-22s best: %s" % [id, str(size), str(base.get("name", "")), best_key if best_key != "" else "NONE"])
			if best_key == "":
				problems.append("%s %s has no 3-star design" % [id, size])
			elif str(size) == ("3u" if sizes.has("3u") else str(sizes[sizes.size() - 1])):   # each mission's main size
				if best_designs.has(best_key):
					problems.append("%s and %s have the same best design" % [id, str(best_designs[best_key])])
				best_designs[best_key] = str(id)
	for p in problems:
		print("PROBLEM  " + str(p))
	print("MISSION CHECK PASSED" if problems.is_empty() else "MISSION CHECK: %d problem(s)" % problems.size())
	quit(0 if problems.is_empty() else 1)
