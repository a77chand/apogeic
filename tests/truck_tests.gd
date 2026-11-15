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
	check((cfg.get("sensors", []) as Array).size() == 6, "6 sensors")
	check((cfg.get("evidence", []) as Array).size() >= 4, "sources are listed")
	var sl: Dictionary = TruckSim.sensor_by_id(cfg, "structlight")
	check(float(sl["detect"]["dark"]) == 0.97 and str(sl["detect_basis"]["dark"]) == "sourced", "structured light uses the NASA Ames 97% figure, marked sourced")
	check(str(sl["detect_basis"]["dust"]) == "placeholder", "its dust value is marked placeholder")
	for s in cfg["sensors"]:
		check((s as Dictionary).has("basis_note") and (s as Dictionary).has("detect_basis"), str(s["id"]) + " states where its numbers come from")
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
	var cheap: Dictionary = TruckSim.evaluate(cfg, ["camera", "headlights", "radar", "stereo"])
	check(bool(cheap["passed"]), "camera+headlights+radar+stereo wins")
	check(TruckSim.detect_chance(cfg, ["headlights"], "dark") == 0.0, "headlights alone see nothing")
	check(TruckSim.detect_chance(cfg, ["camera", "headlights"], "dark") > TruckSim.detect_chance(cfg, ["camera"], "dark") + 0.5, "headlights let the camera see in the dark")
	check(TruckSim.sensor_by_id(cfg, "thermal").is_empty(), "the unsupported thermal camera is gone")
	check(float(cheap["cost_k"]) < float(rich["cost_k"]), "the cheaper build costs less")

	# limits: every sensor together breaks mass, power and budget
	var all: Dictionary = TruckSim.evaluate(cfg, ["camera", "stereo", "lidar", "radar", "headlights"])
	check(not bool(all["power_ok"]) and not bool(all["cost_ok"]), "all sensors break power and budget")
	check(not bool(all["passed"]), "over the limits means fail")

	# the explanation names the weak condition and a fix
	var cam: Dictionary = TruckSim.evaluate(cfg, ["camera"])
	var text: String = " ".join(PackedStringArray(cam["causes"]))
	check(text.contains("never sees sunlight") and text.contains("Adding a"), "cause chain explains the dark failure and suggests a sensor")

	# route challenges: the solutions found by the level search (route_solve, same rules)
	# still work, and the obvious straight route does not
	var routes: Array = cfg.get("routes", [])
	check(routes.size() == 6, "three route sets and three moving-shadows sets")
	var sols: Dictionary = {
		"route_1": [[0, 3], [0, 2], [0, 1], [0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0], [7, 0], [7, 1], [7, 2], [7, 3], [8, 3], [9, 3], [10, 3], [11, 3], [12, 3], [13, 3]],
		"route_2": [[0, 3], [0, 4], [0, 5], [0, 6], [1, 6], [2, 6], [3, 6], [4, 6], [5, 6], [6, 6], [7, 6], [8, 6], [8, 5], [8, 4], [9, 4], [9, 3], [10, 3], [11, 3], [12, 3], [13, 3]],
		"route_3": [[0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [1, 6], [2, 6], [3, 6], [4, 6], [4, 7], [5, 7], [6, 7], [7, 7], [8, 7], [9, 7], [10, 7], [11, 7], [12, 7], [13, 7], [13, 6], [13, 5], [13, 4], [13, 3]],
		"shadows_1": [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3], [11, 3], [12, 3], [13, 3]],
		"shadows_2": [[0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [4, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3], [11, 3], [12, 3], [13, 3]],
		"shadows": [[0, 3], [0, 3], [0, 3], [1, 3], [2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3], [11, 3], [11, 4], [12, 4], [13, 4]],
	}
	for r in routes:
		var rd: Dictionary = r
		var path: Array = (sols[str(rd["id"])] as Array).map(func(p: Variant) -> Vector2i: return Vector2i(int(p[0]), int(p[1])))
		check(bool(TruckSim.route_eval(cfg, rd, path)["ok"]), str(rd["id"]) + ": the known solution works")
		# straight along the start row to the goal's column, then to the goal: must fail
		var s0: Vector2i = TruckSim.route_find(rd, "S")
		var g0: Vector2i = TruckSim.route_find(rd, "G")
		var straight: Array = [s0]
		var c: Vector2i = s0
		while c.x < g0.x:
			c += Vector2i(1, 0)
			straight.append(c)
		while c.y != g0.y:
			c += Vector2i(0, 1 if g0.y > c.y else -1)
			straight.append(c)
		check(not bool(TruckSim.route_eval(cfg, rd, straight)["ok"]), str(rd["id"]) + ": the straight route fails")
	var back: Array = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 3)]
	check(str(TruckSim.route_eval(cfg, routes[0], back)["fail"]).contains("tracks"), "driving back over its own tracks is not allowed")

	if fails.is_empty():
		print("TRUCK TESTS PASSED")
		quit(0)
	else:
		for f in fails:
			printerr("FAILED: ", f)
		quit(1)
