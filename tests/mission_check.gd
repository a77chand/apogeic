## Checks that every mission can still earn 3 stars with some set of parts (events ignored).
## Slow (tries every combination), so it is not part of run_tests.gd.
##   godot --headless --path . -s tests/mission_check.gd
extends SceneTree
const Sim = preload("res://scripts/core/sim.gd")
const Data = preload("res://scripts/core/data.gd")


func best_stars(level: Dictionary, parts: Dictionary) -> Array:
	var solars := ["solar_small", "solar_large"]
	var batts := ["", "battery_small", "battery_std"]
	var instr := ["camera_std", "spectrometer"]
	var radios := ["radio_uhf", "radio_sband"]
	var extras := [["", ""], ["antenna_big", ""], ["ground2", ""], ["shielding", ""], ["antenna_big", "ground2"], ["antenna_big", "shielding"], ["ground2", "shielding"]]
	var best := 0
	var desc := ""
	for s in solars:
		for b in batts:
			for i in instr:
				for r in radios:
					for ex in extras:
						var design := {"solar": s, "battery": b, "instrument": i, "radio": r, "extra_a": ex[0], "extra_b": ex[1]}
						var sched: Dictionary = Sim.new_schedule()
						sched["day"] = 41
						var ev: Dictionary = Sim.evaluate_design(level, parts, design, sched)
						var results: Array = Sim.check_requirements(level, ev)
						if not bool(Sim.can_launch(ev, results)["ok"]):
							continue
						if not bool(Sim.launch_outcome(level, results, ev).get("reached_orbit", true)):
							continue
						var st: Dictionary = Sim.new_ops_state(level, ev, results)
						var guard := 0
						while not bool(st["ended"]) and guard < 100:
							guard += 1
							Sim.ops_week(level, ev, st, {})
						var stars: int = int(Sim.score_mission(level, st, results)["stars"])
						if stars > best:
							best = stars
							desc = str(design.values())
	return [best, desc]


func _initialize() -> void:
	var parts: Dictionary = Data.load_parts()
	var bad := 0
	for id in Data.MISSIONS:
		var level: Dictionary = Data.load_level(str(id))
		var r: Array = best_stars(level, parts)
		print("%-8s %-22s best %d stars  %s" % [id, str(level.get("name", "")), r[0], r[1]])
		if int(r[0]) < 3:
			bad += 1
	print("MISSION CHECK PASSED" if bad == 0 else "MISSION CHECK: %d missions cannot reach 3 stars" % bad)
	quit(0)
