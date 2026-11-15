## Plays through the real screens, the way a player would, and checks that each screen
## opens and that a mission actually flies: test lab, launch, operations (sped up), report.
## It answers event cards on its own. The save file is copied first and put back at the end.
##   godot --headless --path . -s tests/flow_check.gd
extends SceneTree

var fails: Array = []
var gs: Node = null


func check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)
		print("FAIL  " + what)


func _initialize() -> void:
	run.call_deferred()


func current() -> String:
	return str(gs.router.call("current_id"))


## Clicks the first choice on any event card or tip box that is open.
func answer_popups() -> void:
	for c in root.find_children("*", "Control", true, false):
		if c.has_signal("chosen") and is_instance_valid(c) and not bool(c.get("_done")):
			c.call("_on_choice", 0)
		elif c.has_method("_finish") and c.get_script() != null and str(c.get_script().resource_path).ends_with("tutorial.gd"):
			c.call("_finish")


func wait(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		await process_frame
		answer_popups()
		t += 1.0 / 60.0 * Engine.time_scale


func run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	gs = root.get_node("GameState")
	var saved_file: String = FileAccess.get_file_as_string(gs.SAVE_PATH) if FileAccess.file_exists(gs.SAVE_PATH) else ""
	gs.set("tips_on", false)
	# every screen opens
	for id in ["title", "guide", "profile", "ladder", "puzzle_mass", "puzzle_power", "puzzle_link", "puzzle_time", "missions", "trivia", "truck", "truck_route", "briefing", "workshop"]:
		gs.go(id)
		await wait(0.3)
		check(current() == id, "screen opens: " + id)
	# fly missions 1 and 2 with a design that can earn 3 stars
	var designs: Dictionary = {
		"level1": {"solar": "solar_small", "battery": "battery_small", "instrument": "camera_std", "radio": "radio_uhf", "extra_a": "antenna_big", "extra_b": "ground2"},
		"level4": {"solar": "solar_small", "battery": "battery_small", "instrument": "camera_std", "radio": "radio_uhf", "extra_a": "antenna_big", "extra_b": "ground2"},
		"level2": {"solar": "solar_small", "battery": "battery_small", "instrument": "spectrometer", "radio": "radio_uhf", "extra_a": "ground2", "extra_b": ""},
	}
	Engine.time_scale = 30.0
	for mid in designs.keys():
		gs.set_mission(mid)
		var d: Dictionary = designs[mid]
		for k in d.keys():
			gs.set_slot(k, d[k])
		gs.go("test_lab")
		await wait(2.0)
		check(current() == "test_lab", mid + ": test lab opens")
		gs.go("launch")
		var guard: int = 0
		while current() != "ops" and guard < 4000:
			await process_frame
			answer_popups()
			guard += 1
		check(current() == "ops", mid + ": launch goes on to operations")
		guard = 0
		while current() != "report" and guard < 20000:
			await process_frame
			answer_popups()
			guard += 1
		check(current() == "report", mid + ": operations ends in the report")
		var delivered: float = float(gs.ops.get("delivered_mb", 0.0))
		print("%s delivered %.0f MB, stars %d" % [mid, delivered, int(gs.mission_stars.get(mid, 0))])
		check(delivered > 0.0, mid + ": data reaches the ground")
	Engine.time_scale = 1.0
	# put the player's save back exactly as it was
	if saved_file != "":
		var f: FileAccess = FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
		f.store_string(saved_file)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SAVE_PATH))
	print("FLOW CHECK PASSED" if fails.is_empty() else "FLOW CHECK: %d failure(s)" % fails.size())
	quit(0 if fails.is_empty() else 1)
