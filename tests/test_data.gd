## Checks that every data/*.json file loads and every number has a source.
## Run from the project folder:
##   godot --headless --script res://tests/test_data.gd
extends SceneTree

const GameData = preload("res://scripts/sim/game_data.gd")


func _init() -> void:
	var data := GameData.load_all()
	var errors: Array = data.errors
	# Cross-file checks: ids used in one file must exist in another.
	if errors.is_empty():
		var modules: Dictionary = data.modules.modules
		var events: Dictionary = data.events.events
		for prio_id in data.modules.power_priorities:
			for module_id in data.modules.power_priorities[prio_id].order:
				if not modules.has(module_id):
					errors.append("power_priorities.%s names unknown module %s" % [prio_id, module_id])
		for scen_id in data.scenarios.scenarios:
			var scen: Dictionary = data.scenarios.scenarios[scen_id]
			for module_id in scen.start_modules:
				if not modules.has(module_id):
					errors.append("scenario %s starts with unknown module %s" % [scen_id, module_id])
			for event_id in scen.event_chances:
				if not events.has(event_id):
					errors.append("scenario %s has odds for unknown event %s" % [scen_id, event_id])
			for sched in scen.scheduled_events:
				if not events.has(sched.event):
					errors.append("scenario %s schedules unknown event %s" % [scen_id, sched.event])
		for step in data.tutorial.steps:
			if step.goal_build != "" and not modules.has(step.goal_build):
				errors.append("tutorial sol %d asks for unknown module %s" % [step.sol, step.goal_build])
	if errors.is_empty():
		print("DATA OK: %d modules, %d events, %d scenarios" % [
			data.modules.modules.size(), data.events.events.size(), data.scenarios.scenarios.size()])
		quit(0)
	else:
		for e in errors:
			printerr("DATA ERROR: ", e)
		quit(1)
