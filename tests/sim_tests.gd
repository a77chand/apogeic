extends RefCounted
## Checks for the game rules. No scenes needed.
## Run from a terminal:   godot --headless --path . --script res://tests/run_tests.gd
## Or press "Run self-test" on the title screen.
## Expected numbers were worked out separately from the same data files.
## If you change data/*.json on purpose, update the numbers here in the same commit.

const Data = preload("res://scripts/core/data.gd")
const Sim = preload("res://scripts/core/sim.gd")


static func _near(fails: Array, name: String, got: float, want: float) -> void:
	if absf(got - want) > 0.01:
		fails.append("%s: got %s, wanted %s" % [name, str(got), str(want)])


static func _same(fails: Array, name: String, got: Variant, want: Variant) -> void:
	if got != want:
		fails.append("%s: got %s, wanted %s" % [name, str(got), str(want)])


static func _design(level: Dictionary, solar: String, battery: String, instrument: String, radio: String, extra_a: String, extra_b: String) -> Dictionary:
	var d: Dictionary = Sim.new_design(level)
	d["solar"] = solar
	d["battery"] = battery
	d["instrument"] = instrument
	d["radio"] = radio
	d["extra_a"] = extra_a
	d["extra_b"] = extra_b
	return d


## Plays a whole mission with fixed choices. storm and ground are choice indexes (0 or 1).
static func _fly(level: Dictionary, parts: Dictionary, events: Array, design: Dictionary, sched: Dictionary, storm: int, ground: int, extra_pass: bool) -> Dictionary:
	var ev: Dictionary = Sim.evaluate_design(level, parts, design, sched)
	var results: Array = Sim.check_requirements(level, ev)
	var st: Dictionary = Sim.new_ops_state(level, ev, results)
	var guard: int = 0
	while not bool(st["ended"]) and guard < 100:
		guard += 1
		var next_week: int = int(st["week"]) + 1
		var due: Array = Data.events_for(events, "ops", next_week)
		for item in due:
			var event: Dictionary = item
			var pick: int = storm
			if str(event.get("id", "")) == "ground_silent":
				pick = ground
			Sim.apply_ops_choice(st, ev["part_ids"], event, pick)
		Sim.ops_week(level, ev, st, {"extra_pass": extra_pass})
	return {"ev": ev, "results": results, "st": st, "score": Sim.score_mission(level, st, results)}


## Returns a list of failure messages. An empty list means everything passed.
static func run() -> Array:
	var fails: Array = []
	var parts: Dictionary = Data.load_parts()
	var level: Dictionary = Data.load_level1()
	var puzzles: Dictionary = Data.load_puzzles()
	var events: Array = Data.load_events()
	_same(fails, "parts loaded", parts.size(), 11)
	_same(fails, "requirements loaded", (level.get("requirements", []) as Array).size(), 6)
	_same(fails, "events loaded", events.size(), 11)
	if not fails.is_empty():
		return fails

	# --- the reference design: small panels, standard battery, camera, S-band radio
	var base: Dictionary = _design(level, "solar_small", "battery_std", "camera_std", "radio_sband", "", "")
	var sched: Dictionary = Sim.new_schedule()
	sched["day"] = 41
	var ev: Dictionary = Sim.evaluate_design(level, parts, base, sched)
	_near(fails, "base mass", ev["mass_kg"], 3.4)
	_near(fails, "base power use", ev["power_use_w"], 12.4)
	_near(fails, "base power spare", ev["power_spare_pct"], 11.43)
	_near(fails, "base eclipse", ev["eclipse_min_pct"], 81.92)
	_near(fails, "base delivered", ev["delivered_mb_wk"], 36.0)
	_same(fails, "base launch day", ev["launch_day"], 121)
	_near(fails, "base total cost", ev["total_cost_k"], 781.0)
	_near(fails, "base reserve", ev["reserve_pct"], 21.9)
	var results: Array = Sim.check_requirements(level, ev)
	_same(fails, "base R1", Sim.result_by_id(results, "R1")["passed"], true)
	_same(fails, "base R2", Sim.result_by_id(results, "R2")["passed"], false)
	_same(fails, "base R6", Sim.result_by_id(results, "R6")["passed"], true)
	_near(fails, "base readiness", Sim.readiness_pct(results), 83.33)
	_same(fails, "base can launch", Sim.can_launch(ev, results)["ok"], true)

	# --- a winning design: add the second ground station
	var good: Dictionary = _design(level, "solar_small", "battery_std", "camera_std", "radio_sband", "ground2", "")
	var good_ev: Dictionary = Sim.evaluate_design(level, parts, good, sched)
	_same(fails, "good all pass", Sim.all_passed(Sim.check_requirements(level, good_ev)), true)
	_near(fails, "good delivered", good_ev["delivered_mb_wk"], 54.0)

	# --- hard failures
	var heavy: Dictionary = _design(level, "solar_large", "battery_std", "camera_std", "radio_sband", "antenna_big", "shielding")
	var heavy_ev: Dictionary = Sim.evaluate_design(level, parts, heavy, sched)
	_near(fails, "heavy mass", heavy_ev["mass_kg"], 4.3)
	_same(fails, "heavy cannot launch", Sim.can_launch(heavy_ev, Sim.check_requirements(level, heavy_ev))["ok"], false)
	var empty: Dictionary = Sim.new_design(level)
	var empty_ev: Dictionary = Sim.evaluate_design(level, parts, empty, sched)
	_same(fails, "empty missing count", (empty_ev["missing"] as Array).size(), 3)
	_same(fails, "empty cannot launch", Sim.can_launch(empty_ev, Sim.check_requirements(level, empty_ev))["ok"], false)
	_near(fails, "empty spare", empty_ev["power_spare_pct"], -100.0)

	# --- wrong instrument and no radio
	var wrong: Dictionary = _design(level, "solar_large", "battery_std", "spectrometer", "radio_sband", "", "")
	_near(fails, "spectrometer delivers nothing useful", Sim.evaluate_design(level, parts, wrong, sched)["delivered_mb_wk"], 0.0)
	var no_radio: Dictionary = _design(level, "solar_small", "battery_std", "camera_std", "", "antenna_big", "ground2")
	_near(fails, "no radio sends nothing", Sim.evaluate_design(level, parts, no_radio, sched)["send_mb_wk"], 0.0)

	# --- schedule: finishing late slips the launch
	var late: Dictionary = Sim.new_schedule()
	late["day"] = 131
	var late_ev: Dictionary = Sim.evaluate_design(level, parts, base, late)
	_same(fails, "late launch day", late_ev["launch_day"], 181)
	var late_res: Array = Sim.check_requirements(level, late_ev)
	_same(fails, "late R6", Sim.result_by_id(late_res, "R6")["passed"], false)
	var late_st: Dictionary = Sim.new_ops_state(level, late_ev, late_res)
	_near(fails, "late money after slip", late_st["money_k"], 69.0)
	_same(fails, "late slipped", late_st["slipped"], true)

	# --- pre-launch event
	var ev_sched: Dictionary = Sim.new_schedule()
	ev_sched["day"] = 41
	var vib: Dictionary = Data.events_for(events, "test_lab", 0)[0]
	Sim.apply_prelaunch_choice(ev_sched, [], vib, 0)
	_same(fails, "repair adds days", ev_sched["extra_days"], 10)
	_near(fails, "repair adds cost", ev_sched["extra_cost_k"], 20.0)
	Sim.apply_prelaunch_choice(ev_sched, [], vib, 1)
	_near(fails, "fly as is cuts send", ev_sched["send_mult"], 0.75)
	var ev2: Dictionary = Sim.evaluate_design(level, parts, good, ev_sched)
	_near(fails, "event send", ev2["send_mb_wk"], 40.5)
	_near(fails, "event cost", ev2["total_cost_k"], 901.0)

	# --- storage fills up when the radio is too slow
	var st: Dictionary = Sim.new_ops_state(level, ev, results)
	for i in range(5):
		Sim.ops_week(level, ev, st, {})
	_near(fails, "week 5 stored", st["stored_mb"], 80.0)
	_near(fails, "week 5 delivered", st["delivered_mb"], 180.0)
	_near(fails, "week 5 lost", st["lost_mb"], 40.0)

	# --- whole missions
	var m1: Dictionary = _fly(level, parts, events, base, sched, 0, 0, false)
	_near(fails, "m1 delivered", m1["st"]["delivered_mb"], 360.0)
	_same(fails, "m1 grade", m1["score"]["grade"], "partial")
	_same(fails, "m1 stars", m1["score"]["stars"], 1)
	var m2: Dictionary = _fly(level, parts, events, base, sched, 1, 1, true)
	_near(fails, "m2 delivered", m2["st"]["delivered_mb"], 450.0)
	_near(fails, "m2 money", m2["st"]["money_k"], 149.0)
	var m3: Dictionary = _fly(level, parts, events, good, sched, 0, 0, false)
	_near(fails, "m3 delivered", m3["st"]["delivered_mb"], 540.0)
	_near(fails, "m3 money", m3["st"]["money_k"], 119.0)
	_same(fails, "m3 stars", m3["score"]["stars"], 3)
	_same(fails, "m3 grade", m3["score"]["grade"], "success")
	_same(fails, "m3 end", m3["st"]["end_reason"], "complete")
	var no_batt: Dictionary = _design(level, "solar_small", "", "camera_std", "radio_sband", "", "")
	var m4: Dictionary = _fly(level, parts, events, no_batt, sched, 0, 0, false)
	_same(fails, "m4 end", m4["st"]["end_reason"], "no_battery")
	_same(fails, "m4 week", m4["st"]["week"], 1)
	_same(fails, "m4 stars", m4["score"]["stars"], 0)
	_same(fails, "m4 has causes", Sim.build_causes(m4["ev"], m4["results"], m4["st"]).size() > 0, true)
	var hungry: Dictionary = _design(level, "solar_small", "battery_std", "spectrometer", "radio_sband", "antenna_big", "")
	var m5: Dictionary = _fly(level, parts, events, hungry, sched, 0, 0, false)
	_same(fails, "m5 end", m5["st"]["end_reason"], "battery_empty")
	_same(fails, "m5 week", m5["st"]["week"], 5)

	# --- launch rule: the share of checks passed must reach the line in level1.json
	var lo1: Dictionary = Sim.launch_outcome(level, m1["results"])
	_same(fails, "lo1 reaches orbit at 83%", lo1["reached_orbit"], true)
	_same(fails, "lo1 climb is full", lo1["climb_pct"], 100.0)
	var lo4: Dictionary = Sim.launch_outcome(level, m4["results"])
	_same(fails, "lo4 fails at 67%", lo4["reached_orbit"], false)
	_near(fails, "lo4 climbs as far as readiness", lo4["climb_pct"], 66.6667)
	_same(fails, "lo3 reaches orbit when all pass", Sim.launch_outcome(level, m3["results"])["reached_orbit"], true)
	var dead: Dictionary = Sim.new_ops_state(level, m4["ev"], m4["results"])
	Sim.fail_launch(dead)
	_same(fails, "fail_launch ends the mission", dead["end_reason"], "launch_failed")
	_same(fails, "fail_launch scores 0 stars", Sim.score_mission(level, dead, m4["results"])["stars"], 0)
	var launch_ev: Dictionary = (m4["ev"] as Dictionary).duplicate()
	launch_ev["launch_min_readiness_pct"] = float(level["launch_min_readiness_pct"])
	var launch_causes: Array = Sim.build_causes(launch_ev, m4["results"], dead)
	_same(fails, "launch failure is the first cause", str(launch_causes[0]["cause"]).contains("rocket needs at least 80%"), true)
	_same(fails, "light design gets the small rocket", Sim.rocket_for_mass(level, 2.0), "small")
	_same(fails, "3.0 kg gets the medium rocket", Sim.rocket_for_mass(level, 3.0), "medium")
	_same(fails, "3.4 kg (85% of the limit) gets the medium rocket", Sim.rocket_for_mass(level, 3.4), "medium")
	_same(fails, "3.8 kg gets the heavy rocket", Sim.rocket_for_mass(level, 3.8), "heavy")

	# --- puzzles
	var p1: Dictionary = puzzles["mass"]
	_same(fails, "p1 good", Sim.puzzle_mass(p1, parts, ["camera_std", "solar_small", "battery_std", "radio_sband"])["passed"], true)
	_same(fails, "p1 heavy", Sim.puzzle_mass(p1, parts, ["camera_std", "solar_large", "battery_std", "radio_sband", "antenna_big"])["passed"], false)
	_same(fails, "p1 missing", (Sim.puzzle_mass(p1, parts, ["spectrometer", "solar_small", "radio_uhf"])["reasons"] as Array).size(), 2)
	var p2: Dictionary = puzzles["power"]
	_same(fails, "p2 start fails", Sim.puzzle_power(p2, 8.0, 4.0)["passed"], false)
	var p2_ok: Dictionary = Sim.puzzle_power(p2, 13.0, 10.0)
	_same(fails, "p2 good", p2_ok["passed"], true)
	_near(fails, "p2 min", p2_ok["min_pct"], 30.0)
	_near(fails, "p2 mass", p2_ok["mass_kg"], 0.645)
	_same(fails, "p2 too heavy", Sim.puzzle_power(p2, 16.0, 8.0)["passed"], false)
	var p3: Dictionary = puzzles["link"]
	_same(fails, "p3 nothing", Sim.puzzle_link(p3, [])["passed"], false)
	_same(fails, "p3 antenna", Sim.puzzle_link(p3, ["antenna"])["passed"], false)
	_same(fails, "p3 lowres", Sim.puzzle_link(p3, ["lowres"])["passed"], false)
	_same(fails, "p3 ground2", Sim.puzzle_link(p3, ["ground2"])["passed"], true)
	_near(fails, "p3 ground2 delivered", Sim.puzzle_link(p3, ["ground2"])["delivered"], 54.0)
	var p4: Dictionary = puzzles["time"]
	_same(fails, "p4 default fails", Sim.puzzle_time(p4, "normal", "full", 60)["passed"], false)
	var p4_ok: Dictionary = Sim.puzzle_time(p4, "normal", "full", 10)
	_same(fails, "p4 good", p4_ok["passed"], true)
	_same(fails, "p4 finish", p4_ok["finish_day"], 150)
	_near(fails, "p4 cost", p4_ok["cost_k"], 360.0)
	_same(fails, "p4 rushed fails", Sim.puzzle_time(p4, "rushed", "full", 0)["passed"], false)
	# --- richer event choices
	var vib2: Dictionary = Data.events_for(events, "test_lab", 0)[0]
	var brace_sched: Dictionary = Sim.new_schedule()
	brace_sched["day"] = 41
	Sim.apply_prelaunch_choice(brace_sched, [], vib2, 2)
	_same(fails, "brace adds days", brace_sched["extra_days"], 4)
	_near(fails, "brace adds mass", Sim.evaluate_design(level, parts, base, brace_sched)["mass_kg"], 3.7)
	var hot_sched: Dictionary = Sim.new_schedule()
	var heater: Dictionary = {"choices": [{"effects": [{"kind": "extra_power_w", "value": 3.0}]}]}
	Sim.apply_prelaunch_choice(hot_sched, [], heater, 0)
	_near(fails, "heater uses power", Sim.evaluate_design(level, parts, base, hot_sched)["power_use_w"], 15.4)
	var boost_st: Dictionary = Sim.new_ops_state(level, ev, results)
	var boost: Dictionary = {"choices": [{"effects": [{"kind": "boost_send", "value": 0.5, "weeks": 1}, {"kind": "battery_pct", "value": -10.0}, {"kind": "bonus_mb", "value": 30.0}]}]}
	Sim.apply_ops_choice(boost_st, [], boost, 0)
	_same(fails, "boost lasts one week", boost_st["temp_send_weeks"], 1)
	_near(fails, "battery cost", boost_st["battery_pct"], 90.0)
	_near(fails, "bonus data", boost_st["stored_mb"], 30.0)
	var slow: Dictionary = Sim.ops_week(level, ev, boost_st, {})
	_same(fails, "boost has run out", boost_st["temp_send_weeks"], 0)
	_near(fails, "boosted week sends half", slow["sent"], 18.0)
	# --- more ways for the launch to fail (all from the player's picks)
	var calm_ev: Dictionary = {"mass_kg": 3.0, "flaws": []}
	_same(fails, "no flaws, no risk", Sim.launch_outcome(level, m3["results"], calm_ev)["reached_orbit"], true)
	var light_flaw: Dictionary = {"mass_kg": 3.0, "flaws": ["the software bug"]}
	_same(fails, "one flaw on a light craft is fine", Sim.launch_outcome(level, m3["results"], light_flaw)["reached_orbit"], true)
	var heavy_flaw: Dictionary = {"mass_kg": 3.3, "flaws": ["the software bug"]}
	_same(fails, "one flaw on a heavy craft fails", Sim.launch_outcome(level, m3["results"], heavy_flaw)["reached_orbit"], false)
	_same(fails, "that failure says why", str(Sim.launch_outcome(level, m3["results"], heavy_flaw)["fail_text"]).contains("heavy"), true)
	var two_flaws: Dictionary = {"mass_kg": 2.5, "flaws": ["a", "b"]}
	_same(fails, "two flaws fail even when light", Sim.launch_outcome(level, m3["results"], two_flaws)["reached_orbit"], false)
	var no_margin: Dictionary = {"mass_kg": 3.9, "flaws": []}
	_same(fails, "no margin with all checks passing is fine", Sim.launch_outcome(level, m3["results"], no_margin)["reached_orbit"], true)
	_same(fails, "no margin with a failed check fails", Sim.launch_outcome(level, m1["results"], no_margin)["reached_orbit"], false)
	var flawed_sched: Dictionary = Sim.new_schedule()
	Sim.apply_prelaunch_choice(flawed_sched, [], Data.events_for(events, "test_lab", 0)[0], 1)
	_same(fails, "fly as it is leaves a flaw", (Sim.evaluate_design(level, parts, base, flawed_sched)["flaws"] as Array).size(), 1)
	# --- fuel
	var fuel_st: Dictionary = Sim.new_ops_state(level, ev, results)
	_near(fails, "full tank at the start", fuel_st["fuel_pct"], 100.0)
	Sim.apply_ops_choice(fuel_st, [], {"choices": [{"effects": [{"kind": "fuel_pct", "value": -30.0}]}]}, 0)
	_near(fails, "a burn uses fuel", fuel_st["fuel_pct"], 70.0)
	Sim.ops_week(level, ev, fuel_st, {})
	_same(fails, "holding the orbit uses fuel every week", float(fuel_st["fuel_pct"]) < 70.0, true)
	var empty_st: Dictionary = Sim.new_ops_state(level, ev, results)
	empty_st["fuel_pct"] = 4.0
	Sim.ops_week(level, ev, empty_st, {})
	_same(fails, "out of fuel ends the mission", empty_st["end_reason"], "out_of_fuel")
	var decay_st: Dictionary = Sim.new_ops_state(level, ev, results)
	Sim.apply_ops_choice(decay_st, [], {"choices": [{"effects": [{"kind": "decay_in_weeks", "value": 2.0}]}]}, 0)
	Sim.ops_week(level, ev, decay_st, {})
	_same(fails, "still flying after one week", decay_st["ended"], false)
	Sim.ops_week(level, ev, decay_st, {})
	_same(fails, "the orbit decays after three weeks", decay_st["end_reason"], "orbit_decay")
	# --- the three missions
	_same(fails, "three missions", Data.MISSIONS.size(), 3)
	var lvl2: Dictionary = Data.load_level("level2")
	var lvl3: Dictionary = Data.load_level("level3")
	_same(fails, "mission 2 loads", str(lvl2.get("goal_data_type", "")), "spectra")
	_same(fails, "mission 3 loads", int(lvl3["limits"]["deadline_day"]), 150)
	_same(fails, "unknown mission is empty", Data.load_level("nope").is_empty(), true)
	var day_sched: Dictionary = Sim.new_schedule()
	day_sched["day"] = 41
	var d2: Dictionary = _design(lvl2, "solar_small", "battery_small", "spectrometer", "radio_uhf", "antenna_big", "")
	var ev_m2: Dictionary = Sim.evaluate_design(lvl2, parts, d2, day_sched)
	_same(fails, "mission 2 reference design passes every check", Sim.all_passed(Sim.check_requirements(lvl2, ev_m2)), true)
	_same(fails, "mission 2 reference reaches orbit", Sim.launch_outcome(lvl2, Sim.check_requirements(lvl2, ev_m2), ev_m2)["reached_orbit"], true)
	var camera_m2: Dictionary = _design(lvl2, "solar_small", "battery_small", "camera_std", "radio_uhf", "antenna_big", "")
	_same(fails, "a camera cannot do the air mission", Sim.result_by_id(Sim.check_requirements(lvl2, Sim.evaluate_design(lvl2, parts, camera_m2, day_sched)), "R2")["passed"], false)
	var d3: Dictionary = _design(lvl3, "solar_large", "battery_small", "camera_std", "radio_sband", "antenna_big", "")
	var ev_m3: Dictionary = Sim.evaluate_design(lvl3, parts, d3, day_sched)
	_same(fails, "mission 3 reference design passes every check", Sim.all_passed(Sim.check_requirements(lvl3, ev_m3)), true)
	var slow_m3: Dictionary = _design(lvl3, "solar_large", "battery_small", "camera_std", "radio_sband", "", "")
	_same(fails, "mission 3 needs the extra antenna", Sim.result_by_id(Sim.check_requirements(lvl3, Sim.evaluate_design(lvl3, parts, slow_m3, day_sched)), "R2")["passed"], false)
	# --- failure stages: where in the launch it goes wrong
	var heavy_stage: Dictionary = Sim.launch_outcome(level, m3["results"], heavy_flaw)
	_same(fails, "heavy and flawed fails at max-Q", heavy_stage["stage"], "max_q")
	_near(fails, "max-Q is early in the climb", heavy_stage["climb_pct"], 35.0)
	var jammed: Dictionary = Sim.launch_outcome(level, m3["results"], {"mass_kg": 2.5, "flaws": ["a", "b"]})
	_same(fails, "two flaws fail at separation", jammed["stage"], "separation")
	_near(fails, "separation is at the top of the climb", jammed["climb_pct"], 100.0)
	var tear: Dictionary = {"mass_kg": 2.5, "flaws": ["the cracked antenna mount"], "part_ids": ["antenna_big"]}
	_same(fails, "cracked mount plus big antenna fails at max-Q", Sim.launch_outcome(level, m3["results"], tear)["stage"], "max_q")
	var no_antenna: Dictionary = {"mass_kg": 2.5, "flaws": ["the cracked antenna mount"], "part_ids": []}
	_same(fails, "cracked mount alone is survivable on a light craft", Sim.launch_outcome(level, m3["results"], no_antenna)["reached_orbit"], true)
	var panels: Dictionary = {"mass_kg": 2.5, "flaws": ["the software bug"], "part_ids": ["solar_large"]}
	_same(fails, "large panels plus a flaw jam at separation", Sim.launch_outcome(level, m3["results"], panels)["stage"], "separation")
	var both: Dictionary = {"mass_kg": 3.3, "flaws": ["a", "b"], "part_ids": []}
	_same(fails, "the earliest problem sets the failure point", Sim.launch_outcome(level, m3["results"], both)["stage"], "max_q")
	_same(fails, "the failure text names the stage", str(Sim.launch_outcome(level, m3["results"], both)["fail_text"]).begins_with("Failure at max-Q"), true)
	return fails
