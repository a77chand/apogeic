## Sol by Sol simulation: all the game rules, and no UI.
##
## How to use it (see scenes/main.gd and tests/test_sim.gd):
##   const GameData = preload("res://scripts/sim/game_data.gd")
##   const OutpostSim = preload("res://scripts/sim/outpost_sim.gd")
##   var sim = OutpostSim.new(GameData.load_all(), "mars", true)  # true = tutorial on
##   var state = sim.new_game(12345)          # same seed -> same game, handy for tests
##   var result = sim.tick(state, {"build": ["solar_panel"], "power_priority": "food"})
##   state = result.state                      # tick() never changes the state you pass in
##   for line in result.report: print(line.text)
##
## The state is a plain Dictionary (see new_game() for its keys), so it is easy to
## print, copy and test. Every balance number comes from the data files.
extends RefCounted

## The six meters shown in the HUD.
const METERS := ["power", "oxygen", "water", "food", "radiation", "health"]
## Meters that modules and crew make and use up.
const RESOURCES := ["power", "oxygen", "water", "food"]

var modules: Dictionary     # modules.json "modules"
var priorities: Dictionary  # modules.json "power_priorities"
var events: Dictionary      # events.json "events"
var crew: Dictionary        # crew.json
var scenario: Dictionary    # one entry of scenarios.json
var scenario_id: String
var tutorial: Dictionary    # tutorial.json, or {} when the tutorial is off

# One random number generator. Its position is saved in state.rng_state after every
# tick, so a saved state always continues the same way.
var _rng := RandomNumberGenerator.new()


func _init(data: Dictionary, p_scenario_id: String, use_tutorial: bool) -> void:
	modules = data.modules.modules
	priorities = data.modules.power_priorities
	events = data.events.events
	crew = data.crew
	scenario_id = p_scenario_id
	scenario = data.scenarios.scenarios[p_scenario_id]
	tutorial = data.tutorial if use_tutorial else {}


# ---------------------------------------------------------------------------
# Starting a game
# ---------------------------------------------------------------------------

func new_game(seed_value: int) -> Dictionary:
	_rng.seed = seed_value
	var state := {
		"scenario": scenario_id,
		"day_word": scenario.day_word,     # "Sol" on Mars, "Day" on the Moon
		"sol": 1,                          # the sol the player is planning now
		"max_sols": int(scenario.max_sols),
		"status": "playing",               # "playing", "won" or "lost"
		"build_points": int(scenario.start_build_points),
		"meters": {},                      # meter id -> float
		"deltas": {},                      # meter id -> change during the last sol
		"modules": {},                     # module id -> how many are finished
		"pending": [],                     # [{module, sols_left}] still being built
		"power_priority": priorities.keys()[0],
		"events": [],                      # [{id, start_sol, duration, target}]
		"last_run": {},                    # module id -> units that worked last sol
		"history": [],                     # one record per finished sol (for the debrief)
		"failure": {},                     # {meter, sol, chain, tip} when lost
		"tutorial": not tutorial.is_empty(),
		"rng_state": 0,
	}
	for m in METERS:
		state.meters[m] = float(scenario.start_meters.get(m, 0))
		state.deltas[m] = 0.0
	for id in modules:
		state.modules[id] = int(scenario.start_modules.get(id, 0))
	for sched in scenario.scheduled_events:
		_add_event(state, sched.event, int(sched.start_sol))
	if state.tutorial:
		for sched in tutorial.scripted_events:
			_add_event(state, sched.event, int(sched.start_sol))
	state.rng_state = _rng.state
	return state


# ---------------------------------------------------------------------------
# Questions the UI can ask (they never change the state)
# ---------------------------------------------------------------------------

func module_name(id: String) -> String:
	return modules[id].name


func build_cost(id: String) -> int:
	return int(modules[id].cost)


## Returns "" if the module can be ordered, otherwise a short reason.
## `planned` lists modules already queued this sol but not yet sent to tick().
func can_build(state: Dictionary, id: String, planned: Array = []) -> String:
	if state.status != "playing":
		return "the mission is over"
	if not modules.has(id):
		return "unknown module"
	var spent := 0
	var same := 0
	for p in planned:
		spent += build_cost(p)
		if p == id:
			same += 1
	if state.build_points - spent < build_cost(id):
		return "not enough build points"
	var owned: int = state.modules[id] + same
	for p in state.pending:
		if p.module == id:
			owned += 1
	if owned >= int(modules[id].max_count):
		return "the base can only have %d" % int(modules[id].max_count)
	return ""


## Events that are happening on `sol`.
func active_events(state: Dictionary, sol: int) -> Array:
	var out := []
	for e in state.events:
		if e.start_sol <= sol and sol < e.start_sol + e.duration:
			out.append(e)
	return out


## Events the crew already knows are coming (within their warning time).
func warnings(state: Dictionary) -> Array:
	var out := []
	for e in state.events:
		var sols_until: int = e.start_sol - state.sol
		if sols_until > 0 and sols_until <= int(events[e.id].warning_sols):
			out.append(e)
	return out


func event_name(id: String) -> String:
	return events[id].name


## Units of a module that are broken today because of equipment failures.
func broken_units(state: Dictionary, id: String) -> int:
	var broken := 0
	for e in active_events(state, state.sol):
		if e.target == id:
			broken += int(events[e.id].effects.get("disable_units", 0))
	return mini(broken, state.modules[id])


## Finished units that are not broken.
func working_units(state: Dictionary, id: String) -> int:
	return state.modules[id] - broken_units(state, id)


## The full mark for each meter's bar. Radiation's "max" is the limit that ends the game.
func meter_max(state: Dictionary, meter: String) -> float:
	if meter == "power":
		var cap := float(scenario.base_power_storage)
		for id in modules:
			if modules[id].has("power_storage"):
				cap += working_units(state, id) * float(modules[id].power_storage)
		return cap
	if meter == "radiation":
		return float(crew.radiation_limit)
	if meter == "health":
		return float(crew.health.max)
	return float(scenario.storage_max[meter])


# ---------------------------------------------------------------------------
# One sol
# ---------------------------------------------------------------------------

## Plays one sol. `actions` = {"build": [module ids], "power_priority": priority id}.
## Returns {"state": new state, "report": [{"kind": "info"|"good"|"warn"|"bad", "text": ...}]}.
func tick(state: Dictionary, actions: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)  # deep copy, so the caller's state stays as it was
	var report: Array = []
	if s.status != "playing":
		return {"state": s, "report": report}
	_rng.state = s.rng_state
	var sol: int = s.sol
	var word: String = s.day_word
	var facts: Array = []  # short notes about what went wrong, used by the failure debrief

	# --- 1. The player's orders ---------------------------------------------
	var prio = actions.get("power_priority", s.power_priority)
	if priorities.has(prio):
		s.power_priority = prio
	for id in actions.get("build", []):
		var why := can_build(s, id)
		if why != "":
			_say(report, "bad", "Could not build %s: %s." % [_a(module_name(id)), why])
			continue
		s.build_points -= build_cost(id)
		var build_time := int(modules[id].build_time)
		if build_time <= 0:
			s.modules[id] += 1
			_say(report, "good", "Built %s." % _a(module_name(id)))
		else:
			s.pending.append({"module": id, "sols_left": build_time})
			_say(report, "info", "Started %s. It will be ready in %d %s." % [
				_a(module_name(id)), build_time, _plural(word, build_time).to_lower()])

	# --- 2. Events happening today -------------------------------------------
	var sunlight := float(scenario.solar_multiplier)
	var storm_dose := 0.0
	for e in active_events(s, sol):
		var fx: Dictionary = events[e.id].effects
		if fx.has("solar_multiplier"):
			sunlight *= float(fx.solar_multiplier)
		if fx.has("storm_dose"):
			storm_dose += float(fx.storm_dose)
		# Breakdowns were already announced when they happened, so skip those here.
		if e.start_sol == sol and e.target == "":
			_say(report, "warn", _day_text(s, events[e.id].start_text))
		facts.append({"type": "event", "event": e.id, "target": e.target, "sol": e.start_sol,
			"key": "event:%s:%d" % [e.id, e.start_sol]})
	for id in modules:
		var broken := broken_units(s, id)
		if broken > 0:
			_say(report, "warn", "%s: %d broken, the crew is fixing it." % [module_name(id), broken])

	# `pool` is what the base has available right now. Modules add to it and take from it.
	var m: Dictionary = s.meters
	var pool := {}
	var made := {}
	var used := {}
	for r in RESOURCES:
		pool[r] = float(m[r])
		made[r] = 0.0
		used[r] = 0.0
	var ran := {}  # module id -> units that worked today

	# --- 3. Modules that need nothing to run (solar panels) -------------------
	for id in modules:
		var def: Dictionary = modules[id]
		if not def.inputs.is_empty() or def.outputs.is_empty():
			continue
		var units := working_units(s, id)
		ran[id] = units
		var factor := sunlight if def.get("uses_sunlight", false) else 1.0
		for r in def.outputs:
			var amount: float = units * float(def.outputs[r]) * factor
			pool[r] += amount
			made[r] += amount
		if units > 0:
			_say(report, "info", "%s made %s." % [_count_name(id, units), _amounts(def.outputs, units * factor)])
	if sunlight < float(scenario.solar_multiplier):
		var pct := int(round(100.0 * sunlight / float(scenario.solar_multiplier)))
		_say(report, "warn", "Sunlight is only %d%% of normal today." % pct)
		facts.append({"type": "low_sun", "pct": pct, "key": "low_sun"})

	# --- 4. The crew's base power (heaters, fans, computers) always comes first
	var base_power := float(crew.base_power_per_sol)
	var cold := false
	if pool.power >= base_power:
		pool.power -= base_power
		used.power += base_power
	else:
		cold = true
		used.power += pool.power
		pool.power = 0.0
		_say(report, "bad", "Not enough power for the heaters and air fans! The crew is cold.")
		facts.append({"type": "cold", "key": "cold"})

	# What the crew will eat, drink and breathe today. Modules may not use this share.
	var crew_size := int(crew.crew_size)
	var crew_needs := {}
	for r in crew.needs_per_person_per_sol:
		crew_needs[r] = float(crew.needs_per_person_per_sol[r]) * crew_size

	# --- 5. Modules that need inputs, in the chosen priority order ------------
	for id in _run_order(s.power_priority):
		var def: Dictionary = modules[id]
		var units := working_units(s, id)
		var count := 0
		var missing := ""
		for i in units:
			missing = _missing_input(def.inputs, pool, crew_needs)
			if missing != "":
				break
			for r in def.inputs:
				pool[r] -= float(def.inputs[r])
				used[r] += float(def.inputs[r])
			for r in def.outputs:
				pool[r] += float(def.outputs[r])
				made[r] += float(def.outputs[r])
			count += 1
		ran[id] = count
		if units == 0:
			continue
		if count < units:
			_say(report, "bad", "%s: %d of %d switched off, not enough %s." % [
				module_name(id), units - count, units, missing])
			facts.append({"type": "off", "module": id, "missing": missing, "key": "off:%s:%s" % [id, missing]})
		if count > 0 and not def.outputs.is_empty():
			_say(report, "info", "%s made %s." % [_count_name(id, count), _amounts(def.outputs, count)])
	s.last_run = ran

	# --- 6. The crew eats, drinks and breathes ----------------------------------
	for r in crew_needs:
		pool[r] -= crew_needs[r]
		used[r] += crew_needs[r]

	# Storage is limited. Extra power is wasted when the batteries are full.
	for r in RESOURCES:
		var cap := meter_max(s, r)
		if pool[r] > cap:
			if r == "power" and pool[r] - cap >= 1.0:
				_say(report, "info", "Batteries full: %s power wasted. More batteries would save it." % _fmt(pool[r] - cap))
			pool[r] = cap

	# --- 7. Radiation ----------------------------------------------------------
	var shielding := 0.0
	var shelter_factor := 1.0
	for id in modules:
		var def: Dictionary = modules[id]
		var units := working_units(s, id)
		if def.has("background_dose_reduction"):
			shielding += units * float(def.background_dose_reduction)
		if def.has("storm_dose_factor") and units > 0:
			shelter_factor = minf(shelter_factor, float(def.storm_dose_factor))
	shielding = clampf(shielding, 0.0, 1.0)
	var background_dose := float(scenario.background_dose) * (1.0 - shielding)
	var storm_taken := storm_dose * shelter_factor
	var dose := background_dose + storm_taken
	if storm_dose > 0.0:
		if shelter_factor < 1.0:
			_say(report, "good", "The crew hid in the storm shelter: %s radiation instead of %s." % [_fmt(storm_taken), _fmt(storm_dose)])
		else:
			_say(report, "bad", "No storm shelter! The solar particle event gave the crew %s radiation." % _fmt(storm_taken))
			facts.append({"type": "unsheltered", "dose": storm_taken, "key": "unsheltered:%d" % sol})
	var shield_note := " (shielding blocked %d%%)" % int(round(shielding * 100.0)) if shielding > 0.0 else ""
	_say(report, "info", "Radiation today: %s%s." % [_fmt(dose), shield_note])

	# --- 8. Crew health and morale ----------------------------------------------
	var h: Dictionary = crew.health
	var health_change := -float(h.stress_per_sol)
	var beds := 0
	for id in modules:
		var def: Dictionary = modules[id]
		if def.has("morale_per_sol"):
			health_change += ran.get(id, 0) * float(def.morale_per_sol)  # only powered habitats help
		if def.has("crew_capacity"):
			beds += s.modules[id] * int(def.crew_capacity)
	if health_change < 0.0:
		facts.append({"type": "stress", "key": "stress"})
	var no_bed := crew_size - beds
	if no_bed > 0:
		health_change -= no_bed * float(h.crowding_penalty)
		_say(report, "bad", "%d crew have no bed. Build a habitat." % no_bed)
		facts.append({"type": "crowded", "key": "crowded"})
	if cold:
		health_change -= float(h.cold_penalty)
	if dose > float(h.radiation_sickness_threshold):
		health_change -= float(h.radiation_sickness_penalty)
		_say(report, "bad", "That much radiation made the crew sick.")
		facts.append({"type": "sick", "key": "sick:%d" % sol})
	for r in crew_needs:
		if pool[r] > 0.0 and pool[r] < float(h.low_supply_threshold) * meter_max(s, r):
			health_change -= float(h.low_supply_penalty)
			_say(report, "warn", "%s is running low. The crew is rationing and worried." % r.capitalize())
			facts.append({"type": "low_supply", "meter": r, "key": "low:%s" % r})

	# --- 9. Update the meters -----------------------------------------------------
	var old: Dictionary = m.duplicate()
	for r in RESOURCES:
		m[r] = pool[r]
	m.radiation += dose
	m.health = clampf(m.health + health_change, 0.0, float(h.max))
	for r in RESOURCES:
		if made[r] > 0.0 or used[r] > 0.0:
			_say(report, "info", "%s: made %s, used %s." % [r.capitalize(), _fmt(made[r]), _fmt(used[r])])

	# --- 10. Did the mission fail? -----------------------------------------------
	var failed := ""
	for r in crew.fail_at_zero:
		if m[r] <= 0.0:
			failed = r
			break
	if failed == "" and m.radiation >= float(crew.radiation_limit):
		failed = "radiation"
	for r in RESOURCES:
		m[r] = maxf(m[r], 0.0)  # never show a negative bar
	for k in METERS:
		s.deltas[k] = m[k] - old[k]
	s.history.append({
		"sol": sol, "meters": m.duplicate(), "deltas": s.deltas.duplicate(),
		"made": made, "used": used, "facts": facts, "sunlight": sunlight,
		"background_dose": background_dose, "storm_dose": storm_taken,
	})

	if failed != "":
		s.status = "lost"
		s.failure = {
			"meter": failed,
			"sol": sol,
			"chain": explain_failure(s, failed),
			"tip": crew.debrief[failed].tip,
		}
		_say(report, "bad", "MISSION FAILED: " + crew.debrief[failed].fail)
		s.rng_state = _rng.state
		return {"state": s, "report": report}

	if sol >= s.max_sols:
		s.status = "won"
		_say(report, "good", "MISSION COMPLETE! The crew survived %d %s." % [s.max_sols, _plural(word, s.max_sols)])
		s.rng_state = _rng.state
		return {"state": s, "report": report}

	# --- 11. Get ready for the next sol ---------------------------------------
	s.sol = sol + 1
	var still_building := []
	for p in s.pending:
		p.sols_left -= 1
		if p.sols_left <= 0:
			s.modules[p.module] += 1
			_say(report, "good", "The %s is finished and working." % module_name(p.module))
		else:
			still_building.append(p)
	s.pending = still_building
	s.build_points += int(scenario.build_points_per_sol)
	_roll_events(s)
	_announce_upcoming(s, report)
	s.rng_state = _rng.state
	return {"state": s, "report": report}


# ---------------------------------------------------------------------------
# Failure debrief: turn the notes from each sol into a cause chain
# ---------------------------------------------------------------------------

## Returns a list of lines like "Sol 12: Dust storm began." ending with the failure.
func explain_failure(s: Dictionary, meter: String) -> Array:
	var hist: Array = s.history
	var last := hist.size() - 1
	var word: String = s.day_word
	# Look back to when this meter started falling. Radiation builds up over the
	# whole game, so for radiation we look at everything.
	var first := last
	if meter == "radiation":
		first = 0
	else:
		while first > 0 and float(hist[first - 1].deltas[meter]) < 0.0:
			first -= 1
	var related := _related_modules(meter)
	var lines := []
	var seen := {}
	for i in range(first, last + 1):
		var rec: Dictionary = hist[i]
		for f in rec.facts:
			if seen.has(f.key):
				continue
			var text := _fact_text(f, meter, related)
			if text == "":
				continue
			seen[f.key] = true
			# Events remember the sol they began, which can be before the window.
			lines.append("%s %d: %s" % [word, int(f.get("sol", rec.sol)), text])
	# Add the numbers behind the failure.
	if meter in RESOURCES:
		var total_made := 0.0
		var total_used := 0.0
		for i in range(first, last + 1):
			total_made += float(hist[i].made[meter])
			total_used += float(hist[i].used[meter])
		var n := last - first + 1
		lines.append("From %s %d on, the base made about %s %s per %s but used about %s." % [
			word, hist[first].sol, _fmt(total_made / n), meter, word.to_lower(), _fmt(total_used / n)])
	elif meter == "radiation":
		var background := 0.0
		for rec in hist:
			background += float(rec.background_dose)
		lines.append("Everyday radiation added %s in total over %d %s." % [_fmt(background), hist.size(), _plural(word, hist.size()).to_lower()])
	lines.append("%s %d: %s" % [word, hist[last].sol, crew.debrief[meter].fail])
	return lines


## Modules that make `meter`, plus the modules that make what those need.
## Example: food <- greenhouse, which needs water <- ice miner.
func _related_modules(meter: String) -> Array:
	var out := []
	for id in modules:
		if modules[id].outputs.has(meter):
			out.append(id)
		if meter == "health" and modules[id].has("morale_per_sol"):
			out.append(id)
	var direct := out.duplicate()
	for id in direct:
		for r in modules[id].inputs:
			for other in modules:
				if modules[other].outputs.has(r) and not out.has(other):
					out.append(other)
	return out


## One line of the debrief, or "" if this fact didn't contribute to this failure.
func _fact_text(f: Dictionary, meter: String, related: Array) -> String:
	var affects_power := meter != "radiation"
	match f.type:
		"event":
			var fx: Dictionary = events[f.event].effects
			if fx.has("disable_units"):
				if related.has(f.target) or (affects_power and modules[f.target].get("uses_sunlight", false)):
					var thing := _a(module_name(f.target))
					return "%s broke down." % (thing.substr(0, 1).to_upper() + thing.substr(1))
				return ""
			if fx.has("solar_multiplier") and affects_power:
				return "%s began." % event_name(f.event)
			if fx.has("storm_dose") and (meter == "radiation" or meter == "health"):
				return "%s hit the base." % event_name(f.event)
		"low_sun":
			if affects_power:
				if f.pct <= 0:
					return "There was no sunlight, so the solar panels made no power."
				return "Sunlight dropped to %d%%, so the solar panels made less power." % f.pct
		"cold":
			if meter == "health":
				return "Not enough power for the heaters. The crew got cold."
		"off":
			if related.has(f.module):
				return "%s switched off: not enough %s." % [module_name(f.module), f.missing]
		"unsheltered":
			if meter == "radiation" or meter == "health":
				return "No storm shelter, so the crew took %s radiation." % _fmt(f.dose)
		"sick":
			if meter == "health":
				return "Radiation made the crew sick."
		"crowded":
			if meter == "health":
				return "Not enough beds. Crowding hurt the crew."
		"stress":
			if meter == "health":
				return "Hard work and isolation wore the crew down faster than the habitats could cheer them up."
		"low_supply":
			if meter == "health" or meter == f.meter:
				return "%s ran low and the crew had to ration." % str(f.meter).capitalize()
	return ""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _add_event(state: Dictionary, id: String, start_sol: int, target: String = "") -> void:
	var def: Dictionary = events[id]
	var duration := _rng.randi_range(int(def.duration_min), int(def.duration_max))
	state.events.append({"id": id, "start_sol": start_sol, "duration": duration, "target": target})


## Rolls random events at the end of a sol. Events with a warning start later so
## the player has time to react.
func _roll_events(s: Dictionary) -> void:
	var random_from := 1
	if s.tutorial:
		random_from = int(tutorial.random_events_from_sol)
	for id in scenario.event_chances:
		var chance := float(scenario.event_chances[id])
		if chance <= 0.0 or _rng.randf() >= chance:
			continue
		var def: Dictionary = events[id]
		var start: int = s.sol + int(def.warning_sols)
		if start > s.max_sols or start < random_from:
			continue
		if _overlaps_same_event(s, id, start):
			continue
		var target := ""
		if def.has("targets"):
			var candidates := []
			for t in def.targets:
				if working_units(s, t) > 0:
					candidates.append(t)
			if candidates.is_empty():
				continue
			target = candidates[_rng.randi_range(0, candidates.size() - 1)]
		_add_event(s, id, start, target)


## True if an event of the same kind is still going (or planned) around `start`.
func _overlaps_same_event(s: Dictionary, id: String, start: int) -> bool:
	var longest := int(events[id].duration_max)
	for e in s.events:
		if e.id == id and e.start_sol + e.duration > start and e.start_sol <= start + longest:
			return true
	return false


## Adds "coming tomorrow" warnings and "something broke" alerts to the report.
func _announce_upcoming(s: Dictionary, report: Array) -> void:
	for e in s.events:
		var def: Dictionary = events[e.id]
		var sols_until: int = e.start_sol - s.sol
		var warning := int(def.warning_sols)
		if warning > 0 and sols_until == warning:
			_say(report, "warn", "WARNING: " + _day_text(s, def.warning_text))
		elif warning == 0 and sols_until == 0 and e.target != "":
			_say(report, "bad", "%s broke down! It will be offline for %d %s." % [
				module_name(e.target), e.duration, _plural(s.day_word, e.duration).to_lower()])


## Modules with inputs, in priority order. Any not named in the order go last.
func _run_order(priority_id: String) -> Array:
	var order: Array = priorities[priority_id].order.duplicate()
	for id in modules:
		if not modules[id].inputs.is_empty() and not order.has(id):
			order.append(id)
	return order


## The first input there isn't enough of, or "" if everything is available.
## Modules may not touch the crew's own share of water, oxygen and food.
func _missing_input(inputs: Dictionary, pool: Dictionary, crew_needs: Dictionary) -> String:
	for r in inputs:
		var available: float = pool[r] - float(crew_needs.get(r, 0.0))
		if available < float(inputs[r]):
			return r
	return ""


func _say(report: Array, kind: String, text: String) -> void:
	report.append({"kind": kind, "text": text})


## "Greenhouse" or "2 Greenhouses".
func _count_name(id: String, n: int) -> String:
	return module_name(id) if n == 1 else "%d %ss" % [n, module_name(id)]


## "12 power, 3 food" for `n` units of a module's outputs.
func _amounts(per_unit: Dictionary, n: float) -> String:
	var parts := []
	for r in per_unit:
		parts.append("%s %s" % [_fmt(float(per_unit[r]) * n), r])
	return ", ".join(parts)


## Event texts say "{day}" so they read "sol" on Mars and "day" on the Moon.
func _day_text(s: Dictionary, text: String) -> String:
	return text.replace("{day}", str(s.day_word).to_lower())


## "a Battery" / "an Electrolyzer".
func _a(noun: String) -> String:
	return ("an " if noun.substr(0, 1).to_lower() in ["a", "e", "i", "o", "u"] else "a ") + noun


func _plural(word: String, n: int) -> String:
	return word if n == 1 else word + "s"


## Whole numbers without ".0", otherwise one decimal place.
func _fmt(x: float) -> String:
	if absf(x - roundf(x)) < 0.05:
		return str(int(roundf(x)))
	return "%.1f" % x
