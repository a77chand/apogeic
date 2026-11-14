extends SceneTree
## Checks the sensing-truck rules. Run from the project folder:
##   godot --headless --path . --script res://tests/truck_tests.gd

const TruckSim = preload("res://scripts/core/truck_sim.gd")

var fails: Array = []


func check(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)


func _initialize() -> void:
	var cfg: Dictionary = TruckSim.load_config()
	check(cfg.size() > 0, "config loads")
	check((cfg.get("sensors", []) as Array).size() == 5, "5 sensors")
	check((cfg.get("conditions", []) as Array).size() == 5, "5 conditions")

	var none: Dictionary = TruckSim.evaluate(cfg, [])
	check(not bool(none["passed"]), "empty build fails")

	# one sensor is never enough: lidar alone is blinded by dust
	var lidar: Dictionary = TruckSim.evaluate(cfg, ["lidar"])
	check(not bool(lidar["passed"]), "lidar alone fails")
	var lidar_dust: float = TruckSim.detect_chance(cfg, ["lidar"], "dust")
	check(absf(lidar_dust - 0.55) < 0.0001, "single sensor chance is its own number")

	# fusion: lidar + radar in dust = 1 - 0.45 * 0.15
	var fused: float = TruckSim.detect_chance(cfg, ["lidar", "radar"], "dust")
	check(absf(fused - (1.0 - 0.45 * 0.15)) < 0.0001, "fusion multiplies miss chances")

	# a winning build, and a cheaper winning build (no perfect build)
	var rich: Dictionary = TruckSim.evaluate(cfg, ["lidar", "radar", "camera"])
	check(bool(rich["passed"]), "lidar+radar+camera wins")
	var cheap: Dictionary = TruckSim.evaluate(cfg, ["camera", "radar", "thermal"])
	check(bool(cheap["passed"]), "camera+radar+thermal wins")
	check(float(cheap["cost_k"]) < float(rich["cost_k"]), "the cheaper build costs less")

	# limits: every sensor together breaks mass, power and budget
	var all: Dictionary = TruckSim.evaluate(cfg, ["camera", "stereo", "lidar", "radar", "thermal"])
	check(not bool(all["power_ok"]) and not bool(all["cost_ok"]), "all sensors break power and budget")
	check(not bool(all["passed"]), "over the limits means fail")

	# the explanation names the weak condition and a fix
	var cam: Dictionary = TruckSim.evaluate(cfg, ["camera"])
	var text: String = " ".join(PackedStringArray(cam["causes"]))
	check(text.contains("Dark") and text.contains("Adding a"), "cause chain explains the dark failure and suggests a sensor")

	if fails.is_empty():
		print("TRUCK TESTS PASSED")
		quit(0)
	else:
		for f in fails:
			printerr("FAILED: ", f)
		quit(1)
