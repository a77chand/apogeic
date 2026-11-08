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
	await tutorial_walkthrough(main)

	# The rest of the checks play without the tutorial.
	main.top_bar.tutorial_check.button_pressed = false
	await process_frame
	check(not main.state.tutorial and not main.tutorial_panel.visible, "Tutorial checkbox off starts a game without the guide")

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

	# Lose on purpose: end sols without building until something runs out.
	main.start_game()
	var guard := 0
	while main.state.status == "playing" and guard < 40:
		main.end_sol()
		guard += 1
	check(main.state.status == "lost", "doing nothing loses the game")
	check(main.end_screen.visible and not main.report_panel.visible, "end screen replaces the report")
	check(main.end_screen.title.text == "Mission failed", "end screen says Mission failed")
	var steps: int = main.state.failure.chain.size()
	# Each step is a box, with an arrow between boxes.
	check(main.end_screen.chain_list.get_child_count() == steps * 2 - 1, "cause chain shows %d steps with arrows" % steps)
	check(main.end_screen.tip_label.text.begins_with("Tip: "), "end screen shows a tip")
	check(main.top_bar.end_sol_button.disabled, "End sol is disabled after the mission ends")
	print("     debrief: ", main.state.failure.chain)

	# Try the other planet from the end screen.
	var before: String = main.scenario_id
	main.end_screen.switch_button.pressed.emit()
	check(main.scenario_id != before and main.state.sol == 1 and not main.end_screen.visible, "end screen switches planet and restarts")

	# Win: jump to the last sol with a healthy base, then end it.
	main.state.sol = main.state.max_sols
	main.state.meters.oxygen = 40.0
	main.state.meters.water = 60.0
	main.state.meters.food = 60.0
	main.end_sol()
	check(main.state.status == "won" and main.end_screen.title.text == "Mission complete!", "surviving the last sol shows Mission complete")
	main.end_screen.restart_button.pressed.emit()
	check(main.state.sol == 1 and main.state.status == "playing", "Try again restarts")

	finish()


## Plays sols 1-5 the way the tutorial asks and checks the shelter saves the crew.
func tutorial_walkthrough(main) -> void:
	check(main.state.sol == 1 and main.tutorial_panel.visible, "tutorial panel shows on sol 1")
	check(main.tutorial_panel.goal_module(main.sim, main.state) == "solar_panel", "sol 1 goal is a solar panel")
	check(main.top_bar.end_sol_button.disabled, "End sol waits for the tutorial goal")
	main.end_sol()
	check(main.state.sol == 1, "end_sol() does nothing while the goal is missing")
	var expected := {1: "solar_panel", 2: "electrolyzer", 3: "storm_shelter"}
	for sol in [1, 2, 3]:
		var goal: String = expected[sol]
		if sol == 3:
			# The tutorial storm arrives on sol 4, so on sol 3 the alerts must warn about it.
			var alert_texts := []
			for label in main.alerts_panel.list.get_children():
				alert_texts.append(label.text)
			check(alert_texts.has("Next sol: Solar particle event"), "alerts warn one sol ahead (got %s)" % str(alert_texts))
		check(main.tutorial_panel.goal_module(main.sim, main.state) == goal, "sol %d goal is %s" % [sol, goal])
		main.build_menu.buttons[goal].pressed.emit()
		check(not main.top_bar.end_sol_button.disabled, "End sol unlocks once %s is planned" % goal)
		check(main.tutorial_panel.goal_label.text.begins_with("Done!"), "goal shows as done")
		main.top_bar.end_sol_button.pressed.emit()
		main.report_panel.continue_button.pressed.emit()
	check(main.state.sol == 4 and main.state.modules.storm_shelter == 1, "shelter is finished by sol 4")
	var alerts := []
	for label in main.alerts_panel.list.get_children():
		alerts.append(label.text)
	check(alerts.has("Now: Solar particle event (1 sol left)"), "storm is active on sol 4 (alerts: %s)" % str(alerts))
	check(main.tutorial_panel.body.text.contains("hides in the shelter"), "sol 4 text praises the shelter")
	main.top_bar.end_sol_button.pressed.emit()
	var dose: float = main.state.history[-1].storm_dose
	check(dose > 0.0 and dose < 10.0, "shelter cut the storm dose to %s" % dose)
	var saw_shelter_line := false
	for line in main.last_report:
		if line.text.begins_with("The crew hid in the storm shelter"):
			saw_shelter_line = true
	check(saw_shelter_line, "report says the shelter saved the crew")
	main.report_panel.continue_button.pressed.emit()
	check(main.state.sol == 5 and main.tutorial_panel.visible, "sol 5 free-play intro shows")
	main.top_bar.end_sol_button.pressed.emit()
	check(main.state.sol == 6 and not main.tutorial_panel.visible, "tutorial ends after sol 5")

	# Skipping hides the guide and unlocks End sol straight away.
	main.start_game()
	main.tutorial_panel.skip_button.pressed.emit()
	check(not main.tutorial_panel.visible and not main.top_bar.end_sol_button.disabled, "Skip tutorial hides it and unlocks End sol")


func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures.append(message)


func finish() -> void:
	print("\nALL UI CHECKS PASSED" if failures.is_empty() else "\n%d UI CHECK(S) FAILED" % failures.size())
	quit(0 if failures.is_empty() else 1)
