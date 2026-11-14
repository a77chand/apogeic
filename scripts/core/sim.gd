extends RefCounted
## All game rules. Pure static functions: Dictionaries in, Dictionaries out.
## This script never touches nodes, scenes, autoloads, input or time.
## Use it through a preload:  const Sim = preload("res://scripts/core/sim.gd")
##
## JSON note: every number that comes out of a JSON file is a float, and every
## value read from a Dictionary is a Variant. That is why this file wraps values
## in float(), int() and str() and never uses := on a Dictionary value.

const EPS: float = 0.0001


# ---------------------------------------------------------------- design

## A fresh schedule record for one mission attempt.
static func new_schedule() -> Dictionary:
	return {
		"day": 1,             # current workshop day
		"retests": 0,         # failed test lab visits
		"extra_days": 0,      # days added by events
		"extra_cost_k": 0.0,  # money added by events, in thousand dollars
		"send_mult": 1.0,     # permanent radio multiplier from events
		"make_mult": 1.0,     # permanent instrument multiplier from events
	}


## An empty design: one entry per slot id, each holding a part id or "".
static func new_design(level: Dictionary) -> Dictionary:
	var slots: Dictionary = {}
	var slot_list: Array = level.get("slots", [])
	for item in slot_list:
		var slot: Dictionary = item
		slots[str(slot.get("id", ""))] = ""
	return slots


## Works out every number the dashboard shows.
## design: { slot_id: part_id or "" }   parts: parts keyed by id   sched: see new_schedule()
static func evaluate_design(level: Dictionary, parts: Dictionary, design: Dictionary, sched: Dictionary) -> Dictionary:
	var bus: Dictionary = level.get("bus", {})
	var launch: Dictionary = level.get("launch", {})
	var limits: Dictionary = level.get("limits", {})
	var orbit: Dictionary = level.get("orbit", {})
	var sc: Dictionary = level.get("schedule", {})

	var part_ids: Array = []
	for slot_id in design.keys():
		var chosen: String = str(design[slot_id])
		if chosen != "" and parts.has(chosen):
			part_ids.append(chosen)

	var mass: float = float(bus.get("mass_kg", 0.0))
	var gen: float = 0.0
	var use: float = float(bus.get("power_use_w", 0.0))
	var wh: float = 0.0
	var make: float = 0.0
	var send: float = 0.0
	var parts_cost: float = 0.0
	var data_type: String = ""
	var has_radio: bool = false
	for pid in part_ids:
		var p: Dictionary = parts[pid]
		mass += float(p.get("mass_kg", 0.0))
		gen += float(p.get("power_gen_w", 0.0))
		use += float(p.get("power_use_w", 0.0))
		wh += float(p.get("battery_wh", 0.0))
		parts_cost += float(p.get("cost_k", 0.0))
		send += float(p.get("send_mb_wk", 0.0))
		var cat: String = str(p.get("category", ""))
		if cat == "instrument":
			make += float(p.get("make_mb_wk", 0.0))
			data_type = str(p.get("data_type", ""))
		elif cat == "radio":
			has_radio = true
	if not has_radio:
		send = 0.0  # antennas and ground stations do nothing without a radio
	make *= float(sched.get("make_mult", 1.0))
	send *= float(sched.get("send_mult", 1.0))

	var spare_pct: float = -100.0
	if gen > 0.0:
		spare_pct = (gen - use) / gen * 100.0

	var eclipse_pct: float = 0.0
	if wh > 0.0:
		var need_wh: float = use * float(orbit.get("eclipse_min", 0.0)) / 60.0
		eclipse_pct = maxf(0.0, 100.0 * (1.0 - need_wh / wh))

	var useful: bool = data_type == str(level.get("goal_data_type", ""))
	var delivered: float = 0.0
	if useful:
		delivered = minf(make, send)

	var ready_day: int = int(sched.get("day", 1)) + int(sc.get("post_build_days", 0)) \
			+ int(sc.get("retest_days", 0)) * int(sched.get("retests", 0)) + int(sched.get("extra_days", 0))
	var launch_day: int = maxi(ready_day, int(sc.get("licence_days", 0)) + 1)
	var staff_cost: float = float(sc.get("staff_cost_k_per_day", 0.0)) * float(launch_day)
	var total_cost: float = float(bus.get("cost_k", 0.0)) + float(launch.get("cost_k", 0.0)) \
			+ parts_cost + staff_cost + float(sched.get("extra_cost_k", 0.0))
	var budget: float = float(limits.get("budget_k", 1.0))
	var reserve_pct: float = (budget - total_cost) / budget * 100.0

	var missing: Array = []
	var slot_list: Array = level.get("slots", [])
	for item in slot_list:
		var slot: Dictionary = item
		if bool(slot.get("required", false)) and str(design.get(str(slot.get("id", "")), "")) == "":
			missing.append(str(slot.get("label", "")))

	return {
		"part_ids": part_ids,
		"missing": missing,
		"mass_kg": mass,
		"power_gen_w": gen,
		"power_use_w": use,
		"power_spare_pct": spare_pct,
		"battery_wh": wh,
		"eclipse_min_pct": eclipse_pct,
		"make_mb_wk": make,
		"send_mb_wk": send,
		"delivered_mb_wk": delivered,
		"data_useful": useful,
		"parts_cost_k": parts_cost,
		"launch_day": launch_day,
		"staff_cost_k": staff_cost,
		"total_cost_k": total_cost,
		"reserve_pct": reserve_pct,
		"money_left_k": budget - total_cost,
	}


# ---------------------------------------------------------------- requirements

## Which evaluate_design() number each requirement kind reads.
static func _value_key(kind: String) -> String:
	match kind:
		"mass_max":
			return "mass_kg"
		"delivered_min":
			return "delivered_mb_wk"
		"power_spare_min":
			return "power_spare_pct"
		"budget_reserve_min":
			return "reserve_pct"
		"eclipse_min":
			return "eclipse_min_pct"
		"launch_day_max":
			return "launch_day"
	return ""


## One result per requirement, in the order of the level file.
## Each result: id, text, passed, value, target, unit, hard, reason, tip, consequence
static func check_requirements(level: Dictionary, ev: Dictionary) -> Array:
	var out: Array = []
	var req_list: Array = level.get("requirements", [])
	for item in req_list:
		var req: Dictionary = item
		var kind: String = str(req.get("kind", ""))
		var value: float = float(ev.get(_value_key(kind), 0.0))
		var target: float = float(req.get("target", 0.0))
		var passed: bool = false
		if kind.ends_with("_max"):
			passed = value <= target + EPS
		else:
			passed = value >= target - EPS
		out.append({
			"id": str(req.get("id", "")),
			"text": str(req.get("text", "")),
			"passed": passed,
			"value": value,
			"target": target,
			"unit": str(req.get("unit", "")),
			"hard": bool(req.get("hard", false)),
			"reason": str(req.get("reason", "")),
			"tip": str(req.get("tip", "")),
			"consequence": str(req.get("consequence", "")),
		})
	return out


## Share of requirements that pass, 0 to 100.
static func readiness_pct(results: Array) -> float:
	if results.is_empty():
		return 0.0
	var passed: int = 0
	for item in results:
		var r: Dictionary = item
		if bool(r.get("passed", false)):
			passed += 1
	return 100.0 * float(passed) / float(results.size())


static func all_passed(results: Array) -> bool:
	for item in results:
		var r: Dictionary = item
		if not bool(r.get("passed", false)):
			return false
	return true


static func result_by_id(results: Array, id: String) -> Dictionary:
	for item in results:
		var r: Dictionary = item
		if str(r.get("id", "")) == id:
			return r
	return {}


## Launching with failed checks is allowed, except for hard failures.
## Returns { "ok": bool, "reason": String }
static func can_launch(ev: Dictionary, results: Array) -> Dictionary:
	var missing: Array = ev.get("missing", [])
	if not missing.is_empty():
		return {"ok": false, "reason": "The spacecraft is not complete. Missing: " + ", ".join(PackedStringArray(missing)) + "."}
	for item in results:
		var r: Dictionary = item
		if bool(r.get("hard", false)) and not bool(r.get("passed", false)):
			return {"ok": false, "reason": str(r.get("consequence", "This check must pass before launch."))}
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------- events

static func _choice(event: Dictionary, index: int) -> Dictionary:
	var choices: Array = event.get("choices", [])
	if index < 0 or index >= choices.size():
		return {}
	var c: Dictionary = choices[index]
	return c


static func _is_protected(choice: Dictionary, part_ids: Array) -> bool:
	var protect: String = str(choice.get("protect_part", ""))
	return protect != "" and part_ids.has(protect)


## Applies a choice made before launch (when == "test_lab"). Changes sched. Returns the log line.
static func apply_prelaunch_choice(sched: Dictionary, part_ids: Array, event: Dictionary, index: int) -> String:
	var choice: Dictionary = _choice(event, index)
	if choice.is_empty():
		return ""
	if _is_protected(choice, part_ids):
		return str(choice.get("log_protected", ""))
	var effects: Array = choice.get("effects", [])
	for item in effects:
		var fx: Dictionary = item
		var value: float = float(fx.get("value", 0.0))
		match str(fx.get("kind", "")):
			"add_days":
				sched["extra_days"] = int(sched.get("extra_days", 0)) + int(value)
			"add_cost_k":
				sched["extra_cost_k"] = float(sched.get("extra_cost_k", 0.0)) + value
			"mult_send":
				sched["send_mult"] = float(sched.get("send_mult", 1.0)) * value
			"mult_make":
				sched["make_mult"] = float(sched.get("make_mult", 1.0)) * value
	return str(choice.get("log", ""))


## Applies a choice made in orbit (when == "ops"). Changes the ops state. Returns the log line.
## Call it BEFORE ops_week() for the week the event belongs to.
static func apply_ops_choice(st: Dictionary, part_ids: Array, event: Dictionary, index: int) -> String:
	var choice: Dictionary = _choice(event, index)
	if choice.is_empty():
		return ""
	if _is_protected(choice, part_ids):
		return str(choice.get("log_protected", ""))
	var effects: Array = choice.get("effects", [])
	for item in effects:
		var fx: Dictionary = item
		var value: float = float(fx.get("value", 0.0))
		match str(fx.get("kind", "")):
			"add_cost_k":
				st["money_k"] = float(st.get("money_k", 0.0)) - value
			"mult_send":
				st["send_mult"] = float(st.get("send_mult", 1.0)) * value
			"mult_make":
				st["make_mult"] = float(st.get("make_mult", 1.0)) * value
			"skip_week":
				st["force_safe"] = true
			"skip_send":
				st["force_skip_send"] = true
	return str(choice.get("log", ""))


# ---------------------------------------------------------------- operations

## Does the rocket reach orbit? Fixed rule, no randomness: the share of checks passed
## (readiness) must reach launch_min_readiness_pct in level1.json. Below that the rocket
## climbs only as far as the readiness number says, then the launch fails.
## Returns { reached_orbit, readiness_pct, needed_pct, climb_pct }
static func launch_outcome(level: Dictionary, results: Array) -> Dictionary:
	var needed: float = float(level.get("launch_min_readiness_pct", 0.0))
	var ready: float = readiness_pct(results)
	var ok: bool = ready >= needed - EPS
	var climb: float = 100.0
	if not ok:
		climb = ready
	return {"reached_orbit": ok, "readiness_pct": ready, "needed_pct": needed, "climb_pct": climb}


## Which of "small", "medium" or "heavy" rocket to draw, from the design's mass.
static func rocket_for_mass(level: Dictionary, mass_kg: float) -> String:
	var limit: float = float(level.get("limits", {}).get("mass_kg", 1.0))
	var cfg: Dictionary = level.get("rocket_by_mass", {})
	var fraction: float = mass_kg / maxf(0.001, limit)
	if fraction <= float(cfg.get("small_max_fraction", 0.6)):
		return "small"
	if fraction <= float(cfg.get("medium_max_fraction", 0.9)):
		return "medium"
	return "heavy"


## Ends the mission at launch: the satellite never works.
static func fail_launch(st: Dictionary) -> void:
	st["ended"] = true
	st["alive"] = false
	st["end_reason"] = "launch_failed"


## The state at the moment the satellite is released. results = check_requirements() at launch.
static func new_ops_state(level: Dictionary, ev: Dictionary, results: Array) -> Dictionary:
	var sc: Dictionary = level.get("schedule", {})
	var money: float = float(ev.get("money_left_k", 0.0))
	var slipped: bool = false
	var r6: Dictionary = result_by_id(results, "R6")
	if not r6.is_empty() and not bool(r6.get("passed", true)):
		money -= float(sc.get("slip_fee_k", 0.0)) + float(sc.get("slip_days", 0)) * float(sc.get("staff_cost_k_per_day", 0.0))
		slipped = true
	return {
		"week": 0,
		"battery_pct": 100.0,
		"stored_mb": 0.0,
		"delivered_mb": 0.0,
		"lost_mb": 0.0,
		"money_k": money,
		"make_mult": 1.0,
		"send_mult": 1.0,
		"cooldown": 0,          # weeks until the extra pass can be bought again
		"passes_used": 0,
		"brownout_weeks": 0,
		"force_safe": false,     # set by an event, used up by the next ops_week()
		"force_skip_send": false,
		"slipped": slipped,
		"alive": true,
		"ended": false,
		"history": [],          # one record per week flown, for the report chart
		"end_reason": "",       # complete, no_battery, battery_empty, out_of_money
	}


## Advances the mission by one week. Changes st. Returns what happened this week:
## { "week", "made", "sent", "lost", "safe", "extra_pass", "brownout" }
## act keys (all optional booleans): safe_mode, lowres, extra_pass
static func ops_week(level: Dictionary, ev: Dictionary, st: Dictionary, act: Dictionary) -> Dictionary:
	var o: Dictionary = level.get("ops", {})
	var summary: Dictionary = {"week": int(st.get("week", 0)), "made": 0.0, "sent": 0.0, "lost": 0.0, "safe": false, "extra_pass": false, "brownout": false}
	if bool(st.get("ended", false)):
		return summary
	st["week"] = int(st.get("week", 0)) + 1
	summary["week"] = st["week"]

	var safe: bool = bool(act.get("safe_mode", false)) or bool(st.get("force_safe", false))
	var skip_send: bool = bool(st.get("force_skip_send", false))
	st["force_safe"] = false
	st["force_skip_send"] = false
	summary["safe"] = safe

	var extra_pass: bool = false
	if bool(act.get("extra_pass", false)) and int(st.get("cooldown", 0)) == 0 and not safe and not skip_send:
		extra_pass = true
		st["money_k"] = float(st.get("money_k", 0.0)) - float(o.get("extra_pass_cost_k", 0.0))
		st["cooldown"] = int(o.get("extra_pass_cooldown_weeks", 0)) + 1
		st["passes_used"] = int(st.get("passes_used", 0)) + 1
	summary["extra_pass"] = extra_pass

	if float(ev.get("battery_wh", 0.0)) <= 0.0:
		st["alive"] = false
		st["ended"] = true
		st["end_reason"] = "no_battery"
		return summary

	var battery: float = float(st.get("battery_pct", 0.0))
	var recharge: float = float(o.get("safe_mode_recharge_pct", 0.0))
	if safe:
		battery = minf(100.0, battery + recharge)
	else:
		var made: float = float(ev.get("make_mb_wk", 0.0)) * float(st.get("make_mult", 1.0))
		if bool(act.get("lowres", false)):
			made *= float(o.get("lowres_mult", 1.0))
		if float(ev.get("eclipse_min_pct", 0.0)) < 10.0 - EPS:
			made *= 1.0 - float(o.get("brownout_loss", 0.0))
			st["brownout_weeks"] = int(st.get("brownout_weeks", 0)) + 1
			summary["brownout"] = true
		var cap: float = 0.0
		if not skip_send:
			cap = float(ev.get("send_mb_wk", 0.0)) * float(st.get("send_mult", 1.0))
			if extra_pass:
				cap *= float(o.get("extra_pass_mult", 1.0))
		var stored: float = float(st.get("stored_mb", 0.0)) + made
		var sent: float = minf(stored, cap)
		stored -= sent
		var lost: float = 0.0
		var storage: float = float(o.get("storage_mb", 0.0))
		if stored > storage:
			lost = stored - storage
			stored = storage
		st["stored_mb"] = stored
		st["lost_mb"] = float(st.get("lost_mb", 0.0)) + lost
		if bool(ev.get("data_useful", false)):
			st["delivered_mb"] = float(st.get("delivered_mb", 0.0)) + sent
		summary["made"] = made
		summary["sent"] = sent
		summary["lost"] = lost
		var spare: float = float(ev.get("power_spare_pct", 0.0))
		if spare < 0.0:
			battery -= minf(float(o.get("max_drain_pct", 0.0)), -spare * 2.0)
		else:
			battery = minf(100.0, battery + recharge)

	if int(st.get("cooldown", 0)) > 0:
		st["cooldown"] = int(st.get("cooldown", 0)) - 1

	if battery <= 0.0:
		battery = 0.0
		st["alive"] = false
		st["ended"] = true
		st["end_reason"] = "battery_empty"
	elif float(st.get("money_k", 0.0)) < 0.0:
		st["ended"] = true
		st["end_reason"] = "out_of_money"
	elif int(st.get("week", 0)) >= int(o.get("weeks", 0)):
		st["ended"] = true
		st["end_reason"] = "complete"
	st["battery_pct"] = battery
	var record: Array = st.get("history", [])
	record.append({"week": int(st.get("week", 0)), "battery_pct": battery, "stored_mb": float(st.get("stored_mb", 0.0)),
			"delivered_mb": float(st.get("delivered_mb", 0.0))})
	st["history"] = record
	return summary


## Stars and grade at the end. results = check_requirements() at launch.
## Returns { stars, grade, fraction, star_goal, star_checks, star_budget }
static func score_mission(level: Dictionary, st: Dictionary, results: Array) -> Dictionary:
	var o: Dictionary = level.get("ops", {})
	var stars_cfg: Dictionary = level.get("stars", {})
	var limits: Dictionary = level.get("limits", {})
	var goal: float = float(o.get("goal_mb", 1.0))
	var fraction: float = float(st.get("delivered_mb", 0.0)) / goal
	var star_goal: bool = fraction >= 1.0 - EPS
	var star_checks: bool = all_passed(results)
	var need_money: float = float(limits.get("budget_k", 0.0)) * float(stars_cfg.get("reserve_pct", 0.0)) / 100.0
	var finished: bool = str(st.get("end_reason", "")) == "complete"
	var star_budget: bool = finished and float(st.get("money_k", 0.0)) >= need_money - EPS
	var grade: String = "failed"
	if star_goal:
		grade = "success"
	elif fraction >= float(stars_cfg.get("partial_fraction", 0.6)) - EPS:
		grade = "partial"
	var stars: int = 0
	if star_goal:
		stars += 1
	if star_checks:
		stars += 1
	if star_budget:
		stars += 1
	return {"stars": stars, "grade": grade, "fraction": fraction, "star_goal": star_goal, "star_checks": star_checks, "star_budget": star_budget}


## The plain-language cause chain for the report. Most important first.
## Each entry: { "cause": String, "effect": String, "tip": String }
static func build_causes(ev: Dictionary, results: Array, st: Dictionary) -> Array:
	var out: Array = []
	var reason: String = str(st.get("end_reason", ""))
	if reason == "launch_failed":
		var o: Dictionary = launch_outcome({"launch_min_readiness_pct": float(ev.get("launch_min_readiness_pct", 0.0))}, results)
		out.append({"cause": "Only %d%% of the checks passed, and the rocket needs at least %d%% to reach orbit." % [int(round(float(o["readiness_pct"]))), int(round(float(o["needed_pct"])))], "effect": "The launch failed, so the satellite never reached orbit and never worked.", "tip": "Fix the failed checks first. Aim for the marker on the readiness meter."})
	elif reason == "no_battery":
		out.append({"cause": "The satellite had no battery.", "effect": "It lost power in its first eclipse and never woke up.", "tip": "Add a battery. Every orbit has a dark part."})
	elif reason == "battery_empty":
		out.append({"cause": "The parts used more power than the panels made.", "effect": "The battery drained a little more each week until it was empty in week %d." % int(st.get("week", 0)), "tip": "Use larger panels, or parts that need less power."})
	elif reason == "out_of_money":
		out.append({"cause": "There was no money left in reserve.", "effect": "A cost in orbit emptied the budget and the mission was cancelled in week %d." % int(st.get("week", 0)), "tip": "Keep at least 10% of the budget in reserve."})
	if not bool(ev.get("data_useful", true)):
		out.append({"cause": "The instrument did not match the goal.", "effect": "The mission needed photos, and this instrument cannot take them.", "tip": "Pick the instrument that makes the data the goal asks for."})
	for item in results:
		var r: Dictionary = item
		if not bool(r.get("passed", false)):
			out.append({"cause": str(r.get("reason", "")), "effect": str(r.get("consequence", "")), "tip": str(r.get("tip", ""))})
	if float(st.get("lost_mb", 0.0)) > EPS:
		out.append({"cause": "Photos were made faster than they could be sent.", "effect": "Storage filled up and %d MB of photos were lost." % int(round(float(st.get("lost_mb", 0.0)))), "tip": "Send more each week, or make smaller photos."})
	if out.is_empty():
		out.append({"cause": "Every check passed before launch.", "effect": "The satellite had the mass, power, data link and money it needed.", "tip": "Try again with a cheaper or lighter design."})
	return out


# ---------------------------------------------------------------- puzzles

## Puzzle 1. pz = puzzles.json["mass"], ids = chosen part ids.
## Returns { mass_kg, limit_kg, passed, reasons: Array of String }
static func puzzle_mass(pz: Dictionary, parts: Dictionary, ids: Array) -> Dictionary:
	var mass: float = float(pz.get("bus_kg", 0.0))
	for part_id in ids:
		if parts.has(part_id):
			var p: Dictionary = parts[part_id]
			mass += float(p.get("mass_kg", 0.0))
	var reasons: Array = []
	var needs: Array = pz.get("needs", [])
	for item in needs:
		var need: Dictionary = item
		var want_cat: String = str(need.get("category", ""))
		var want_type: String = str(need.get("data_type", ""))
		var found: bool = false
		for part_id in ids:
			if not parts.has(part_id):
				continue
			var part: Dictionary = parts[part_id]
			var type_ok: bool = want_type == "" or str(part.get("data_type", "")) == want_type
			if str(part.get("category", "")) == want_cat and type_ok:
				found = true
				break
		if not found:
			reasons.append(str(need.get("missing", "")))
	var limit: float = float(pz.get("limit_kg", 0.0))
	if mass > limit + EPS:
		reasons.append("Too heavy by %.1f kg. Swap a part for a lighter one." % (mass - limit))
	return {"mass_kg": mass, "limit_kg": limit, "passed": reasons.is_empty(), "reasons": reasons}


## Puzzle 2. panel_w = average panel power, battery_wh = battery size.
## Returns { min_pct, end_pct, mass_kg, passed, reasons, points }
## points is the chart line: Array of [minute, battery percent], starting at eclipse entry.
static func puzzle_power(pz: Dictionary, panel_w: float, battery_wh: float) -> Dictionary:
	var load_w: float = float(pz.get("load_w", 0.0))
	var period: float = float(pz.get("period_min", 1.0))
	var eclipse: float = float(pz.get("eclipse_min", 0.0))
	var sun: float = period - eclipse
	var min_pct: float = 0.0
	var end_pct: float = 0.0
	if battery_wh > 0.0:
		min_pct = maxf(0.0, 100.0 * (1.0 - load_w * (eclipse / 60.0) / battery_wh))
		var gen_in_sun: float = panel_w * period / sun
		end_pct = clampf(min_pct + (gen_in_sun - load_w) * (sun / 60.0) / battery_wh * 100.0, 0.0, 100.0)
	var mass: float = panel_w * float(pz.get("panel_kg_per_w", 0.0)) + battery_wh * float(pz.get("battery_kg_per_wh", 0.0))
	var reasons: Array = []
	if battery_wh <= 0.0:
		reasons.append("With no battery the satellite switches off in the dark.")
	elif min_pct < float(pz.get("min_level_pct", 0.0)) - EPS:
		reasons.append("The battery runs too low in the eclipse. Make it bigger.")
	if panel_w < load_w - EPS:
		reasons.append("The panels make less power than the satellite uses, so the battery never fills up again.")
	if mass > float(pz.get("mass_limit_kg", 0.0)) + EPS:
		reasons.append("Too heavy. Bigger panels and batteries weigh more.")
	var points: Array = [[0.0, 100.0], [eclipse, min_pct], [period, end_pct]]
	if battery_wh <= 0.0:
		points = [[0.0, 0.0], [eclipse, 0.0], [period, 0.0]]
	return {"min_pct": min_pct, "end_pct": end_pct, "mass_kg": mass, "passed": reasons.is_empty(), "reasons": reasons, "points": points}


## Puzzle 3. selected = Array of option ids that are switched on.
## Returns { make, send, delivered, mass_kg, cost_k, passed, reasons }
static func puzzle_link(pz: Dictionary, selected: Array) -> Dictionary:
	var make: float = float(pz.get("make_mb_wk", 0.0))
	var send: float = float(pz.get("send_mb_wk", 0.0))
	var mass: float = 0.0
	var cost: float = 0.0
	var options: Array = pz.get("options", [])
	for item in options:
		var opt: Dictionary = item
		if selected.has(str(opt.get("id", ""))):
			send += float(opt.get("add_send", 0.0))
			mass += float(opt.get("mass_kg", 0.0))
			cost += float(opt.get("cost_k", 0.0))
			if float(opt.get("set_make", -1.0)) >= 0.0:
				make = float(opt.get("set_make", -1.0))
	var delivered: float = minf(make, send)
	var reasons: Array = []
	if delivered < float(pz.get("need_mb_wk", 0.0)) - EPS:
		reasons.append("Only %d MB a week reaches the ground. The mission needs %d." % [int(round(delivered)), int(round(float(pz.get("need_mb_wk", 0.0))))])
	if mass > float(pz.get("spare_mass_kg", 0.0)) + EPS:
		reasons.append("That adds more mass than the rocket has left.")
	if cost > float(pz.get("spare_cost_k", 0.0)) + EPS:
		reasons.append("That costs more than the money you have left.")
	return {"make": make, "send": send, "delivered": delivered, "mass_kg": mass, "cost_k": cost, "passed": reasons.is_empty(), "reasons": reasons}


static func _option_by_id(options: Array, id: String) -> Dictionary:
	for item in options:
		var opt: Dictionary = item
		if str(opt.get("id", "")) == id:
			return opt
	return {}


## Puzzle 4. build_id and test_id pick an option, licence_start is a day number.
## Returns { passed, reasons, finish_day, cost_k, cost_limit_k, bars }
## bars: Array of { "label", "start", "end" } for the schedule chart.
static func puzzle_time(pz: Dictionary, build_id: String, test_id: String, licence_start: int) -> Dictionary:
	var build: Dictionary = _option_by_id(pz.get("build_options", []), build_id)
	var test: Dictionary = _option_by_id(pz.get("test_options", []), test_id)
	var build_end: int = int(build.get("days", 0))
	var test_end: int = build_end + int(test.get("days", 0))
	var licence_end: int = licence_start + int(pz.get("licence_days", 0))
	var ship_start: int = maxi(test_end, licence_end)
	var finish: int = ship_start + int(pz.get("ship_days", 0))
	var cost: float = float(build.get("cost_k", 0.0)) + float(test.get("cost_k", 0.0)) + float(pz.get("licence_cost_k", 0.0)) \
			+ float(pz.get("ship_cost_k", 0.0)) + float(pz.get("staff_cost_k_per_day", 0.0)) * float(finish)
	var limit: float = float(pz.get("budget_k", 0.0)) * (1.0 - float(pz.get("reserve_pct", 0.0)) / 100.0)
	var launch_day: int = int(pz.get("launch_day", 0))
	var reasons: Array = []
	if finish > launch_day:
		if licence_end > test_end:
			reasons.append("Ready on day %d, after the launch on day %d. The licence is what you are waiting for." % [finish, launch_day])
		else:
			reasons.append("Ready on day %d, after the launch on day %d." % [finish, launch_day])
	if cost > limit + EPS:
		if licence_end > test_end:
			reasons.append("Over budget. The team is paid every day while it waits for the licence.")
		else:
			reasons.append("Over budget. Rushing costs more than it saves here.")
	var bars: Array = [
		{"label": "Build", "start": 0, "end": build_end},
		{"label": "Test", "start": build_end, "end": test_end},
		{"label": "Licence", "start": licence_start, "end": licence_end},
		{"label": "Ship", "start": ship_start, "end": finish},
	]
	return {"passed": reasons.is_empty(), "reasons": reasons, "finish_day": finish, "cost_k": cost, "cost_limit_k": limit, "bars": bars}
