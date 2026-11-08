## Plays a full game in the terminal with scripted actions and prints the meters
## every sol. Also checks a few rules the rest of the game relies on.
## Run from the project folder:
##   godot --headless --path . --script res://tests/test_sim.gd
## Add "-- --verbose" at the end to also print every report line.
extends SceneTree

const GameData = preload("res://scripts/sim/game_data.gd")
const OutpostSim = preload("res://scripts/sim/outpost_sim.gd")

# Builds for the tutorial sols, then a shopping list the bot buys in order
# whenever it can afford the next item.
const TUTORIAL_BUILDS := {1: ["solar_panel"], 2: ["electrolyzer"], 3: ["storm_shelter"]}
const WISH_LIST := [
	"ice_miner", "solar_panel", "solar_panel", "greenhouse", "battery", "solar_panel",
	"greenhouse", "battery", "habitat", "solar_panel", "ice_miner", "regolith_shielding",
	"battery", "solar_panel", "regolith_shielding", "greenhouse",
]

var failures: Array = []
var verbose := false


func _init() -> void:
	verbose = OS.get_cmdline_user_args().has("--verbose")
	var data := GameData.load_all()
	if not data.errors.is_empty():
		printerr("Data errors: ", data.errors)
		quit(1)
		return
	for scenario_id in ["moon", "mars"]:
		var final_a := play(data, scenario_id, 42, true)
		# Same seed and same actions must give exactly the same game.
		var final_b := play(data, scenario_id, 42, false)
		check(JSON.stringify(final_a) == JSON.stringify(final_b), "%s: same seed gave different games" % scenario_id)
	if failures.is_empty():
		print("\nALL CHECKS PASSED")
		quit(0)
	else:
		for f in failures:
			printerr("CHECK FAILED: ", f)
		quit(1)


## Plays one game. Returns the final state.
func play(data: Dictionary, scenario_id: String, seed_value: int, show: bool) -> Dictionary:
	var sim = OutpostSim.new(data, scenario_id, true)
	var state: Dictionary = sim.new_game(seed_value)
	var wish_index := 0
	if show:
		print("\n=== %s (seed %d) ===" % [scenario_id.to_upper(), seed_value])
		print("%-7s %6s %6s %6s %6s %6s %6s  BP  events" % [state.day_word, "power", "oxygen", "water", "food", "rad", "health"])
	while state.status == "playing":
		var sol: int = state.sol
		var builds: Array = []
		if TUTORIAL_BUILDS.has(sol):
			builds = TUTORIAL_BUILDS[sol].duplicate()
		elif sol > 5:
			# Buy down the wish list while the next item is affordable.
			while wish_index < WISH_LIST.size() and sim.can_build(state, WISH_LIST[wish_index], builds) == "":
				builds.append(WISH_LIST[wish_index])
				wish_index += 1
		var actions := {"build": builds, "power_priority": "life_support"}

		var before := JSON.stringify(state)
		var result: Dictionary = sim.tick(state, actions)
		check(JSON.stringify(state) == before, "%s sol %d: tick() changed the state it was given" % [scenario_id, sol])

		var new_state: Dictionary = result.state
		# Tutorial: the shelter ordered on sol 3 must protect the crew on sol 4.
		if sol == 4:
			var rec: Dictionary = new_state.history[-1]
			check(float(rec.storm_dose) > 0.0, "%s: tutorial storm did not hit on sol 4" % scenario_id)
			check(float(rec.storm_dose) < 10.0, "%s: storm shelter did not cut the sol 4 dose (%s)" % [scenario_id, rec.storm_dose])
		if show:
			print_row(sim, new_state, sol, builds)
			if verbose:
				for line in result.report:
					print("          [%s] %s" % [line.kind, line.text])
		state = new_state
	if show:
		print("RESULT: %s on %s %d" % [state.status.to_upper(), state.day_word, state.history[-1].sol])
		if state.status == "lost":
			for line in state.failure.chain:
				print("  -> ", line)
			print("  Tip: ", state.failure.tip)
		var built := []
		for id in state.modules:
			if state.modules[id] > 0:
				built.append("%s x%d" % [id, state.modules[id]])
		print("Base: ", ", ".join(built))
	return state


func print_row(sim, state: Dictionary, sol: int, builds: Array) -> void:
	var rec: Dictionary = state.history[-1]
	var cells := []
	for meter in sim.METERS:
		cells.append("%5.1f%s" % [rec.meters[meter], arrow(rec.deltas[meter])])
	var ev := []
	for e in sim.active_events(state, sol):
		ev.append(e.id if e.target == "" else "%s(%s)" % [e.id, e.target])
	print("%-7d %s %3d  %s%s" % [sol, " ".join(cells), state.build_points, ",".join(ev),
		("  built: " + ",".join(builds)) if not builds.is_empty() else ""])


func arrow(delta: float) -> String:
	if delta > 0.05:
		return "+"
	if delta < -0.05:
		return "-"
	return " "


func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
