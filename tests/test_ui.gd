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
	check(water_bar.delta_label.text != "", "water bar shows a change after a sol")

	# Priority dropdown sends the choice with the next End sol.
	main.top_bar.priority_option.select(1)
	main.top_bar.priority_option.item_selected.emit(1)
	main.top_bar.end_sol_button.pressed.emit()
	check(main.state.power_priority == "food", "priority 'food' reached the sim (got %s)" % main.state.power_priority)

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
