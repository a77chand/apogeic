## Balance check: plays many games with different bot players and prints how
## often each wins and when the others fail. Use it after changing data/*.json.
##   godot --headless --path . --script res://tests/balance.gd -- games=200
## Goal (from the brief): a thoughtful player can win; a careless one fails
## around sol 8 to 15.
extends SceneTree

const GameData = preload("res://scripts/sim/game_data.gd")
const OutpostSim = preload("res://scripts/sim/outpost_sim.gd")

const TUTORIAL_BUILDS := {1: ["solar_panel"], 2: ["electrolyzer"], 3: ["storm_shelter"]}
const BOTS := ["thoughtful", "no_shelter", "careless", "random", "idle"]

var rng := RandomNumberGenerator.new()


func _init() -> void:
	var games := 200
	var trace := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("games="):
			games = int(a.split("=")[1])
		if a.begins_with("trace="):
			trace = a.split("=")[1]  # e.g. trace=moon:thoughtful:1000 prints one game
	var data := GameData.load_all()
	if not data.errors.is_empty():
		printerr(data.errors)
		quit(1)
		return
	if trace != "":
		var parts := trace.split(":")
		play(data, parts[0], parts[1], int(parts[2]), true)
		quit(0)
		return
	print("%-6s %-11s %5s  %-26s %s" % ["mode", "bot", "win%", "fail sol (p10/median/p90)", "what ran out"])
	for scenario_id in ["moon", "mars"]:
		for bot in BOTS:
			var wins := 0
			var fail_sols := []
			var causes := {}
			for g in games:
				var final := play(data, scenario_id, bot, 1000 + g)
				if final.status == "won":
					wins += 1
				else:
					fail_sols.append(int(final.failure.sol))
					causes[final.failure.meter] = causes.get(final.failure.meter, 0) + 1
			fail_sols.sort()
			var spread := "-"
			if not fail_sols.is_empty():
				spread = "%d / %d / %d" % [_pct(fail_sols, 0.1), _pct(fail_sols, 0.5), _pct(fail_sols, 0.9)]
			print("%-6s %-11s %4d%%  %-26s %s" % [scenario_id, bot, roundi(100.0 * wins / games), spread, str(causes)])
	quit(0)


func _pct(sorted: Array, p: float) -> int:
	return sorted[clampi(int(p * sorted.size()), 0, sorted.size() - 1)]


func play(data: Dictionary, scenario_id: String, bot: String, seed_value: int, show := false) -> Dictionary:
	var sim = OutpostSim.new(data, scenario_id, true)
	var state: Dictionary = sim.new_game(seed_value)
	rng.seed = seed_value
	while state.status == "playing":
		var builds: Array = []
		var priority := "life_support"
		if bot == "thoughtful" or bot == "no_shelter":
			priority = choose_priority(sim, state)
		if TUTORIAL_BUILDS.has(state.sol):
			builds = TUTORIAL_BUILDS[state.sol].duplicate()
			if bot == "no_shelter":
				builds.erase("storm_shelter")
		elif state.sol > 3:
			match bot:
				"thoughtful":
					builds = plan_thoughtful(sim, state)
				"no_shelter":
					# Plays well but ignores radiation: no shelter, no shielding.
					builds = plan_thoughtful(sim, state, true)
				"careless":
					builds = plan_careless(sim, state)
				"random":
					builds = plan_random(sim, state)
		var sol: int = state.sol
		var result: Dictionary = sim.tick(state, {"build": builds, "power_priority": priority})
		state = result.state
		if show:
			var mm: Dictionary = state.history[-1].meters
			var ev := []
			for e in sim.active_events(state, sol):
				ev.append(e.id)
			print("%2d pwr %5.1f o2 %5.1f h2o %5.1f food %5.1f rad %5.1f hp %5.1f bp %2d %s %s" % [
				sol, mm.power, mm.oxygen, mm.water, mm.food, mm.radiation, mm.health, state.build_points, ev, builds])
			for line in result.report:
				if line.kind == "bad":
					print("      ", line.text)
	if show:
		print(state.status, " ", state.failure.get("chain", ""))
		print(state.modules)
	return state


## A careful player puts food first when food will run out before oxygen.
func choose_priority(sim, state: Dictionary) -> String:
	var needs: Dictionary = sim.crew.needs_per_person_per_sol
	var food_days: float = state.meters.food / float(needs.food)
	var oxygen_days: float = state.meters.oxygen / float(needs.oxygen)
	return "food" if food_days < oxygen_days else "life_support"


## Counts owned + building + planned units of a module.
func _have(state: Dictionary, planned: Array, id: String) -> int:
	var n: int = state.modules[id] + planned.count(id)
	for p in state.pending:
		if p.module == id:
			n += 1
	return n


## A careful player: keeps power, water, oxygen and food budgets positive,
## stores power for nights/storms, then adds comfort and shielding.
## Saves up for the most urgent need instead of buying cheaper extras.
func plan_thoughtful(sim, state: Dictionary, ignore_radiation := false) -> Array:
	var planned: Array = []
	for i in 12:
		var want := _thoughtful_next(sim, state, planned, ignore_radiation)
		if want == "" or sim.can_build(state, want, planned) != "":
			break  # nothing needed, or save up for it
		planned.append(want)
	return planned


func _thoughtful_next(sim, state: Dictionary, planned: Array, ignore_radiation := false) -> String:
	var m: Dictionary = sim.modules
	var crew_n := int(sim.crew.crew_size)
	var needs: Dictionary = sim.crew.needs_per_person_per_sol
	var have := {}
	for id in m:
		have[id] = _have(state, planned, id)
	# Daily budgets with everything running in normal sunlight.
	var power_in: float = have.solar_panel * float(m.solar_panel.outputs.power) * float(sim.scenario.solar_multiplier)
	var power_out := float(sim.crew.base_power_per_sol)
	for id in m:
		power_out += have[id] * float(m[id].inputs.get("power", 0))
	var water: float = have.ice_miner * float(m.ice_miner.outputs.water) - crew_n * float(needs.water) \
		- have.electrolyzer * float(m.electrolyzer.inputs.water) - have.greenhouse * float(m.greenhouse.inputs.water)
	var oxygen: float = have.electrolyzer * float(m.electrolyzer.outputs.oxygen) - crew_n * float(needs.oxygen)
	var food: float = have.greenhouse * float(m.greenhouse.outputs.food) - crew_n * float(needs.food)
	# Power to survive a dark spell on essentials only (no greenhouses).
	var essentials: float = float(sim.crew.base_power_per_sol) + have.habitat * float(m.habitat.inputs.power) \
		+ have.electrolyzer * float(m.electrolyzer.inputs.power) + have.ice_miner * float(m.ice_miner.inputs.power)
	var storage: float = float(sim.scenario.base_power_storage) + have.battery * float(m.battery.power_storage)
	var dark_sols := 3.0 if sim.scenario_id == "moon" else 2.0
	var storage_needed: float = essentials * dark_sols

	if have.storm_shelter == 0 and not ignore_radiation:
		return "storm_shelter"
	if power_in < power_out + 2.0:
		return "solar_panel"
	if oxygen < 0:
		return "electrolyzer"
	if water < 0:
		return "ice_miner"
	if food < 0 and state.meters.food < 40:
		return "greenhouse"
	if storage < storage_needed:
		# Batteries only help if there is spare power to charge them.
		if power_in < power_out + 6.0:
			return "solar_panel"
		return "battery"
	if have.habitat < 2:
		return "habitat"
	if have.regolith_shielding < int(m.regolith_shielding.max_count) and not ignore_radiation:
		return "regolith_shielding"
	if food < 2:
		return "greenhouse"
	return ""


## A careless player: food and comfort look important, power is boring.
func plan_careless(sim, state: Dictionary) -> Array:
	var planned: Array = []
	for want in ["greenhouse", "habitat", "greenhouse", "solar_panel", "ice_miner"]:
		if sim.can_build(state, want, planned) == "":
			planned.append(want)
	return planned


func plan_random(sim, state: Dictionary) -> Array:
	var planned: Array = []
	var ids: Array = sim.modules.keys()
	for i in 3:
		var want: String = ids[rng.randi_range(0, ids.size() - 1)]
		if sim.can_build(state, want, planned) == "":
			planned.append(want)
	return planned
