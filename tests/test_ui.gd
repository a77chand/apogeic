## Loads the real main scene without a window and clicks through it.
## Run from the project folder:
##   godot --headless --path . --script res://tests/test_ui.gd
extends SceneTree

var failures: Array = []


# _initialize runs once the SceneTree is ready, so we can add scenes and wait frames.
func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	check(main.state.sol == 1, "game starts on sol 1")
	check(main.top_bar.sol_label.text == "Sol 1 / 30", "sol label reads 'Sol 1 / 30' (got '%s')" % main.top_bar.sol_label.text)
	var water_bar = main.meter_panel.meters.get_node("Water")
	check(water_bar.value_label.text == "50 / 60", "water bar shows 50 / 60 (got '%s')" % water_bar.value_label.text)

	# Press End sol twice, the same way a mouse click would.
	main.top_bar.end_sol_button.pressed.emit()
	main.top_bar.end_sol_button.pressed.emit()
	await process_frame
	check(main.state.sol == 3, "End sol advanced to sol 3 (got %d)" % main.state.sol)
	check(main.top_bar.sol_label.text == "Sol 3 / 30", "sol label updated")
	check(main.report_panel.visible, "report pops up after End sol")
	check(main.report_panel.title.text == "Sol 2 report", "report is about the sol that just ended (got '%s')" % main.report_panel.title.text)
	check(main.report_panel.details_list.get_child_count() > 0, "report has detail lines")
	# The tutorial storm arrives on sol 4, so on sol 3 the alerts must warn about it.
	var alert_texts := []
	for label in main.alerts_panel.list.get_children():
		alert_texts.append(label.text)
	check(alert_texts.has("Next sol: Solar particle event"), "alerts warn one sol ahead (got %s)" % str(alert_texts))
	main.report_panel.continue_button.pressed.emit()
	check(not main.report_panel.visible, "Continue closes the report")
	check(water_bar.delta_label.text != "", "water bar shows a change after a sol")

	# Priority dropdown sends the choice with the next End sol.
	main.top_bar.priority_option.select(1)
	main.top_bar.priority_option.item_selected.emit(1)
	main.top_bar.end_sol_button.pressed.emit()
	check(main.state.power_priority == "food", "priority 'food' reached the sim (got %s)" % main.state.power_priority)

	# Build menu: plan two solar panels, check the plan, then end the sol.
	var solar_before: int = main.state.modules.solar_panel
	var points_before: int = main.points_left()
	main.build_menu.buttons["solar_panel"].pressed.emit()
	main.build_menu.buttons["solar_panel"].pressed.emit()
	check(main.planned_builds.size() == 2, "two solar panels planned")
	check(main.points_left() == points_before - 4, "planning spends build points (left %d)" % main.points_left())
	check(main.top_bar.points_label.text == "Build points: %d" % main.points_left(), "top bar shows points left")
	var planned_tiles := 0
	for tile in main.base_view.grid.get_children():
		if tile.status_label.text == "PLANNED":
			planned_tiles += 1
	check(planned_tiles == 2, "base view shows 2 PLANNED tiles (got %d)" % planned_tiles)
	main.build_menu.clear_button.pressed.emit()
	check(main.planned_builds.is_empty(), "Clear plan empties the plan")
	main.build_menu.buttons["solar_panel"].pressed.emit()
	main.top_bar.end_sol_button.pressed.emit()
	check(main.state.modules.solar_panel == solar_before + 1, "planned solar panel was built on End sol")
	check(main.planned_builds.is_empty(), "plan is cleared after End sol")
	# A module you can't afford has a disabled button with a reason.
	main.state.build_points = 0
	main.refresh()
	var hab_button: Button = main.build_menu.buttons["habitat"]
	check(hab_button.disabled and hab_button.tooltip_text.begins_with("Can't build"), "unaffordable module is disabled with a reason")

	# Switching to the Moon starts a new Moon game.
	main.top_bar.moon_button.pressed.emit()
	await process_frame
	check(main.state.scenario == "moon" and main.state.sol == 1, "Moon toggle restarts on the Moon")
	check(main.top_bar.sol_label.text == "Day 1 / 30", "Moon uses 'Day' (got '%s')" % main.top_bar.sol_label.text)

	main.top_bar.end_sol_button.pressed.emit()
	main.top_bar.restart_button.pressed.emit()
	check(main.state.sol == 1, "Restart goes back to day 1")

	finish()


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)


func finish() -> void:
	print("\nALL UI CHECKS PASSED" if failures.is_empty() else "\n%d UI CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
