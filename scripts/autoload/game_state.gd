extends Node
## Autoload named GameState. Holds the loaded data and the state of the current
## play-through. Screens read and write here. Rules live in sim.gd, not here.

signal design_changed

const Data = preload("res://scripts/core/data.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Craft = preload("res://scripts/core/craft.gd")
const SAVE_PATH: String = "user://save.json"

# ---- mission progress rules (see is_mission_open, record_mission_result, the lives below)
const STAGE_SIZE: int = 7               # missions come in stages of 7
const STAGE_STARS_NEEDED: int = 17      # stars (of 21) in a stage to open the next stage
const MAX_LIVES: int = 5
const LIFE_SECONDS: float = 1800.0      # one life comes back every 30 minutes
const STARDUST_PER_PERFECT: int = 500   # the first time a mission gets 3 stars
const LIFE_COST_STARDUST: int = 1500

# ---- loaded once from data/*.json
var parts: Dictionary = {}
var level: Dictionary = {}          # the level for the chosen craft (see set_craft)
var base_level: Dictionary = {}     # level1.json as loaded
var craft_cfg: Dictionary = {}      # data/craft.json
var craft_id: String = "3u"
var mission_id: String = "level1"   # which mission is being played (see Data.MISSIONS)
var puzzles: Dictionary = {}
var events: Array = []

# ---- progress that is saved
var puzzles_done: Dictionary = {}   # puzzle id -> true
var best_stars: int = 0
var missions_done: Dictionary = {}  # mission id -> best grade ("partial" or "success"). Failed does not count
var mission_stars: Dictionary = {}  # mission id -> best stars
var lives: int = MAX_LIVES          # a failed mission (0 stars) costs one, saved
var life_clock: float = 0.0         # unix time the next life started refilling (0 = full)
var stardust: int = 0               # earned by 3-star missions and trivia, spent on lives and advice, saved
var trivia_day: String = ""         # the date of today's trivia rounds, saved
var trivia_rounds: int = 0          # rounds played on trivia_day, saved
var trivia_last: float = 0.0        # unix time the last round finished, saved
var last_reward: Dictionary = {}    # what the last mission earned or cost, for the report (not saved)
var tutorial_seen: Dictionary = {}  # screen id -> true, so each tip shows once
var tips_on: bool = true           # first-visit tips shown at all, saved (off = harder)
var tutorial_open: bool = false     # true while a tip box is on screen (clocks wait)
var muted: bool = false             # sound effects on/off, saved
var sfx_volume: float = 0.8         # sound effects volume, 0..1, saved
var music_volume: float = 0.5       # background music volume, 0..1, saved
var music_muted: bool = false       # background music on/off, saved
var font_size: String = "medium"    # "small", "medium" or "large", saved (see UI.label)
var last_design: Dictionary = {}    # the parts of the last finished attempt, so "Start over" can be undone
var music: Node = null              # set by main.gd (scripts/ui/music.gd)
var player_name: String = ""       # the player's astronaut, saved (see scripts/ui/player.gd)
var player_title: String = "Commander"
var avatar_suit: int = 0            # index into Player.SUITS
var avatar_patch: int = 0           # index into Player.PATCHES
var profile_next: String = "ladder" # where the profile screen goes when it is done (not saved)
var sfx: Node = null                # set by main.gd (scripts/ui/sfx.gd)

# ---- the current mission attempt (reset by reset_mission)
var design: Dictionary = {}         # slot id -> part id or ""
var sched: Dictionary = {}          # see Sim.new_schedule()
var launch_eval: Dictionary = {}    # evaluate() frozen at launch
var launch_results: Array = []      # requirement results frozen at launch
var launch_outcome: Dictionary = {} # Sim.launch_outcome() frozen at launch
var ops: Dictionary = {}            # see Sim.new_ops_state()
var log_lines: Array = []           # event log lines for the report
var events_seen: Dictionary = {}    # event id -> true
var event_picks: Dictionary = {}    # moment key ("ops:4") -> id of the event chosen for this attempt

var router: Node = null             # set by main.gd


func _ready() -> void:
	parts = Data.load_parts()
	base_level = Data.load_level1()
	craft_cfg = Craft.load_config()
	craft_id = str(craft_cfg.get("default", "3u"))
	level = Craft.apply(base_level, craft_cfg, craft_id)
	puzzles = Data.load_puzzles()
	events = Data.load_events()
	load_save()
	reset_mission()


## Plays a sound effect by name ("click", "fit", "ping", "alert", "chime", "fail", "rumble").
## Does nothing when muted or before the sound node exists (for example in headless tests).
func play_sound(id: String) -> void:
	if muted or sfx == null:
		return
	sfx.call("play", id)


func set_muted(value: bool) -> void:
	muted = value
	apply_audio()
	save_game()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_game()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	save_game()


func set_music_muted(value: bool) -> void:
	music_muted = value
	apply_audio()
	save_game()


func set_font_size(value: String) -> void:
	if value in ["small", "medium", "large"]:
		font_size = value
		save_game()


## How much body text is scaled (UI.label reads this).
func font_scale() -> float:
	if font_size == "small":
		return 0.9
	if font_size == "large":
		return 1.15
	return 1.0


## Sends the saved volumes to the sound and music players.
func apply_audio() -> void:
	if sfx != null:
		sfx.call("set_volume", 0.0 if muted else sfx_volume)
	if music != null:
		music.call("set_volume", 0.0 if music_muted else music_volume)


## How much of the game is finished, 0..100: the four training puzzles and every mission.
func progress_pct() -> float:
	var total: int = puzzle_order().size() + Data.MISSIONS.size()
	if total == 0:
		return 0.0
	var done: int = 0
	for id in puzzle_order():
		if is_puzzle_done(str(id)):
			done += 1
	for id in Data.MISSIONS:
		if is_mission_done(str(id)):
			done += 1
	return 100.0 * float(done) / float(total)


## True while a mission attempt is under way (parts fitted, or the satellite is flying).
## The menu asks before leaving, because leaving loses the attempt.
func in_mission() -> bool:
	if router == null:
		return false
	var screen: String = str(router.call("current_id"))
	return screen in ["workshop", "test_lab", "launch", "ops"]


## Keeps the parts of this attempt so "Start over" can be undone from the workshop.
func remember_design() -> void:
	var any: bool = false
	for key in design.keys():
		if str(design[key]) != "":
			any = true
	if any:
		last_design = design.duplicate()


func restore_last_design() -> void:
	if last_design.is_empty():
		return
	for key in last_design.keys():
		if design.has(key):
			design[key] = str(last_design[key])
	design_changed.emit()


## Chooses the craft size (1u, 3u or 6u) and starts a fresh design for it.
func set_craft(id: String) -> void:
	if Craft.by_id(craft_cfg, id).is_empty():
		return
	craft_id = id
	level = Craft.apply(base_level, craft_cfg, id)
	reset_mission()


## Change screen. Screen ids are listed in main.gd.
func go(screen_id: String) -> void:
	if router != null:
		router.call("go", screen_id)


## Picks one event at random for each moment that has several. Called for every new attempt,
## so each run can meet different events. The effects of an event are never random.
func roll_events() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	event_picks = {}
	var slots: Dictionary = Data.event_slots(events, mission_id)
	# a mission based on a real story leans towards the events from that story
	var bias: Array = level.get("event_bias", [])
	for key in slots.keys():
		var ids: Array = slots[key]
		var liked: Array = ids.filter(func(x: Variant) -> bool: return bias.has(str(x)))
		# a mission's own real-life decision always comes up
		var own: Array = ids.filter(func(x: Variant) -> bool: return _event_mission(str(x)) == mission_id)
		if not own.is_empty():
			event_picks[str(key)] = str(own[0])
		elif not liked.is_empty() and rng.randf() < 0.8:
			event_picks[str(key)] = str(liked[rng.randi_range(0, liked.size() - 1)])
		else:
			event_picks[str(key)] = str(ids[rng.randi_range(0, ids.size() - 1)])


func _event_mission(id: String) -> String:
	for item in events:
		var ev: Dictionary = item
		if str(ev.get("id", "")) == id:
			return str(ev.get("mission", ""))
	return ""


## The events that fire at this moment of the current attempt.
func events_due(when: String, week: int) -> Array:
	return Data.events_for(events, when, week, event_picks)


func reset_mission() -> void:
	design = Sim.new_design(level)
	sched = Sim.new_schedule()
	launch_eval = {}
	launch_results = []
	launch_outcome = {}
	ops = {}
	log_lines = []
	events_seen = {}
	roll_events()
	design_changed.emit()


## A new attempt that keeps the parts already chosen. Used by "Retry with changes".
func retry_mission() -> void:
	sched = Sim.new_schedule()
	launch_eval = {}
	launch_results = []
	launch_outcome = {}
	ops = {}
	log_lines = []
	events_seen = {}
	roll_events()
	design_changed.emit()


## Adds one line to the event log shown in the report. Empty lines are ignored.
func add_log(line: String) -> void:
	if line != "":
		log_lines.append(line)


## Current numbers for the dashboard.
func evaluate() -> Dictionary:
	return Sim.evaluate_design(level, parts, design, sched)


## Puts a part in a slot ("" empties it). Returns false if the part does not fit the slot.
func set_slot(slot_id: String, part_id: String) -> bool:
	if not design.has(slot_id):
		return false
	if part_id != "":
		if not parts.has(part_id):
			return false
		var part: Dictionary = parts[part_id]
		if str(part.get("category", "")) != slot_category(slot_id):
			return false
		for other in design.keys():
			if str(other) != slot_id and str(design[other]) == part_id:
				return false  # the same part cannot be used twice
	design[slot_id] = part_id
	design_changed.emit()
	return true


func slot_category(slot_id: String) -> String:
	var slot_list: Array = level.get("slots", [])
	for item in slot_list:
		var slot: Dictionary = item
		if str(slot.get("id", "")) == slot_id:
			return str(slot.get("category", ""))
	return ""


## Freezes the design at launch and creates the ops state.
func begin_ops() -> void:
	launch_eval = evaluate()
	launch_results = Sim.check_requirements(level, launch_eval)
	ops = Sim.new_ops_state(level, launch_eval, launch_results)
	launch_outcome = Sim.launch_outcome(level, launch_results, launch_eval)
	launch_eval["launch_min_readiness_pct"] = float(level.get("launch_min_readiness_pct", 0.0))
	if sched.has("decay_after_weeks"):   # a pre-launch choice that leaves the orbit too low
		ops["decay_week"] = int(sched["decay_after_weeks"])
	if not bool(launch_outcome.get("reached_orbit", true)):
		Sim.fail_launch(ops, str(launch_outcome.get("fail_text", "")))


# ---- missions

## Switches to another mission and starts a fresh attempt at it.
func set_mission(id: String) -> void:
	var loaded: Dictionary = Data.load_level(id)
	if loaded.is_empty():
		return
	mission_id = id
	base_level = loaded
	level = Craft.apply(base_level, craft_cfg, craft_id)
	reset_mission()


func mission_ids() -> Array:
	return Data.MISSIONS


func mission_info(id: String) -> Dictionary:
	return Data.load_level(id)


## A mission counts as done once it has at least one star.
func is_mission_done(id: String) -> bool:
	return stars_for(id) >= 1


func stars_for(id: String) -> int:
	return int(mission_stars.get(id, 0))


func total_stars() -> int:
	var n: int = 0
	for id in Data.MISSIONS:
		n += stars_for(str(id))
	return n


## Missions come in stages of 7: stage 0 is missions 1-7, stage 1 is 8-14, and so on.
func stage_of(index: int) -> int:
	return index / STAGE_SIZE


func stage_stars(stage: int) -> int:
	var n: int = 0
	for i in range(stage * STAGE_SIZE, mini((stage + 1) * STAGE_SIZE, Data.MISSIONS.size())):
		n += stars_for(str(Data.MISSIONS[i]))
	return n


## A stage opens when the stage before it has at least STAGE_STARS_NEEDED stars.
func is_stage_open(stage: int) -> bool:
	return stage <= 0 or stage_stars(stage - 1) >= STAGE_STARS_NEEDED


## A mission is open when it is the first one, or the one before it has at least one star.
## The first mission of a stage also needs the stage before it to have enough stars.
## Finished missions can be replayed in any order.
func is_mission_open(id: String) -> bool:
	var index: int = Data.MISSIONS.find(id)
	if index <= 0:
		return index == 0
	if not is_stage_open(stage_of(index)):
		return false
	return is_mission_done(str(Data.MISSIONS[index - 1]))


## Why a mission is locked, in one short line.
func lock_reason(id: String) -> String:
	var index: int = Data.MISSIONS.find(id)
	var stage: int = stage_of(index)
	if not is_stage_open(stage):
		return "Needs %d of %d stars in missions %d-%d (you have %d)" % [STAGE_STARS_NEEDED, STAGE_SIZE * 3, (stage - 1) * STAGE_SIZE + 1, stage * STAGE_SIZE, stage_stars(stage - 1)]
	return "Earn a star in mission %d first" % index


## The mission "Go to next mission" starts: the one after the current mission if it is
## open, otherwise the first open mission with no stars yet, otherwise the current one.
func next_mission_id() -> String:
	var index: int = Data.MISSIONS.find(mission_id)
	if index >= 0 and index + 1 < Data.MISSIONS.size() and is_mission_open(str(Data.MISSIONS[index + 1])) and stars_for(mission_id) >= 1:
		return str(Data.MISSIONS[index + 1])
	for item in Data.MISSIONS:
		var id: String = str(item)
		if is_mission_open(id) and stars_for(id) == 0:
			return id
	return mission_id


# ---- lives and star dust

## Gives back any lives that have refilled since the clock started.
func refresh_lives() -> void:
	if lives >= MAX_LIVES:
		lives = MAX_LIVES
		life_clock = 0.0
		return
	var now: float = Time.get_unix_time_from_system()
	if life_clock <= 0.0:
		life_clock = now
	while lives < MAX_LIVES and now - life_clock >= LIFE_SECONDS:
		lives += 1
		life_clock += LIFE_SECONDS
	if lives >= MAX_LIVES:
		life_clock = 0.0


## Seconds until the next life comes back (0 when lives are full).
func seconds_to_next_life() -> int:
	refresh_lives()
	if lives >= MAX_LIVES:
		return 0
	return maxi(0, int(ceil(LIFE_SECONDS - (Time.get_unix_time_from_system() - life_clock))))


func lose_life() -> void:
	refresh_lives()
	if lives >= MAX_LIVES:
		life_clock = Time.get_unix_time_from_system()
	lives = maxi(0, lives - 1)
	save_game()


func buy_life() -> bool:
	refresh_lives()
	if lives >= MAX_LIVES or stardust < LIFE_COST_STARDUST:
		return false
	stardust -= LIFE_COST_STARDUST
	lives += 1
	if lives >= MAX_LIVES:
		life_clock = 0.0
	save_game()
	return true


# ---- trivia: up to 3 rounds a day, 10 minutes apart (numbers in data/trivia.json)

## {"ok": can a round start now, "wait": seconds until it can, "left": rounds left today,
## "why": a short reason when it cannot}
func trivia_status(cfg: Dictionary) -> Dictionary:
	var today: String = Time.get_date_string_from_system()
	var played: int = trivia_rounds if trivia_day == today else 0
	var per_day: int = int(cfg.get("rounds_per_day", 3))
	var left: int = maxi(0, per_day - played)
	if left <= 0:
		return {"ok": false, "wait": 0, "left": 0, "why": "Come back tomorrow! You have played all %d rounds today." % per_day}
	var wait: int = int(ceil(float(cfg.get("cooldown_minutes", 10)) * 60.0 - (Time.get_unix_time_from_system() - trivia_last)))
	if played > 0 and wait > 0:
		return {"ok": false, "wait": wait, "left": left, "why": "Next round in %d:%02d." % [wait / 60, wait % 60]}
	return {"ok": true, "wait": 0, "left": left, "why": ""}


func finish_trivia_round(earned: int) -> void:
	var today: String = Time.get_date_string_from_system()
	if trivia_day != today:
		trivia_day = today
		trivia_rounds = 0
	trivia_rounds += 1
	trivia_last = Time.get_unix_time_from_system()
	stardust += earned
	save_game()


func can_start_mission() -> bool:
	refresh_lives()
	return lives > 0


## Called when the mission ends. grade is "success", "partial" or "failed".
func record_mission_result(grade: String, stars: int) -> void:
	last_reward = {}
	if stars >= 3 and stars_for(mission_id) < 3:
		stardust += STARDUST_PER_PERFECT
		last_reward["stardust"] = STARDUST_PER_PERFECT
	if stars <= 0:
		lose_life()
		last_reward["life_lost"] = true
	if grade != "failed":
		if grade == "success" or not missions_done.has(mission_id):
			missions_done[mission_id] = grade
	if stars > int(mission_stars.get(mission_id, 0)):
		mission_stars[mission_id] = stars
	save_game()


# ---- puzzle ladder

func puzzle_order() -> Array:
	var order: Array = puzzles.get("order", [])
	return order


func is_puzzle_done(id: String) -> bool:
	return bool(puzzles_done.get(id, false))


## A puzzle is open when it is the first one or the one before it is done.
func is_puzzle_open(id: String) -> bool:
	var order: Array = puzzle_order()
	var index: int = order.find(id)
	if index <= 0:
		return index == 0
	return is_puzzle_done(str(order[index - 1]))


func mark_puzzle_done(id: String) -> void:
	puzzles_done[id] = true
	save_game()


func mark_tutorial_seen(id: String) -> void:
	tutorial_seen[id] = true
	save_game()


## Makes every tip show again (title screen button).
func reset_tutorial() -> void:
	tutorial_seen = {}
	save_game()


func record_stars(stars: int) -> void:
	if stars > best_stars:
		best_stars = stars
	save_game()


# ---- save file

func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save file.")
		return
	file.store_string(JSON.stringify({"puzzles_done": puzzles_done, "best_stars": best_stars, "tutorial_seen": tutorial_seen, "muted": muted, "missions_done": missions_done, "mission_stars": mission_stars,
			"player_name": player_name, "player_title": player_title, "avatar_suit": avatar_suit, "avatar_patch": avatar_patch,
			"sfx_volume": sfx_volume, "music_volume": music_volume, "music_muted": music_muted, "font_size": font_size, "tips_on": tips_on, "trivia_day": trivia_day, "trivia_rounds": trivia_rounds, "trivia_last": trivia_last,
			"lives": lives, "life_clock": life_clock, "stardust": stardust}))
	file.close()


func load_save() -> void:
	puzzles_done = {}
	best_stars = 0
	missions_done = {}
	mission_stars = {}
	tutorial_seen = {}
	muted = false
	sfx_volume = 0.8
	music_volume = 0.5
	music_muted = false
	font_size = "medium"
	player_name = ""
	player_title = "Commander"
	avatar_suit = 0
	avatar_patch = 0
	lives = MAX_LIVES
	life_clock = 0.0
	stardust = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Dictionary = Data.load_dict(SAVE_PATH)
	var done: Variant = data.get("puzzles_done", {})
	if typeof(done) == TYPE_DICTIONARY:
		puzzles_done = done
	best_stars = int(data.get("best_stars", 0))
	muted = bool(data.get("muted", false))
	var done_missions: Variant = data.get("missions_done", {})
	if typeof(done_missions) == TYPE_DICTIONARY:
		missions_done = done_missions
	var star_record: Variant = data.get("mission_stars", {})
	if typeof(star_record) == TYPE_DICTIONARY:
		mission_stars = star_record
	player_name = str(data.get("player_name", "")).left(14)
	player_title = str(data.get("player_title", "Commander"))
	avatar_suit = int(data.get("avatar_suit", 0))
	avatar_patch = int(data.get("avatar_patch", 0))
	sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.5)), 0.0, 1.0)
	music_muted = bool(data.get("music_muted", false))
	font_size = str(data.get("font_size", "medium"))
	tips_on = bool(data.get("tips_on", true))
	trivia_day = str(data.get("trivia_day", ""))
	trivia_rounds = int(data.get("trivia_rounds", 0))
	trivia_last = float(data.get("trivia_last", 0.0))
	lives = clampi(int(data.get("lives", MAX_LIVES)), 0, MAX_LIVES)
	life_clock = float(data.get("life_clock", 0.0))
	stardust = maxi(0, int(data.get("stardust", 0)))
	refresh_lives()
	var seen: Variant = data.get("tutorial_seen", {})
	if typeof(seen) == TYPE_DICTIONARY:
		tutorial_seen = seen


func set_tips_on(value: bool) -> void:
	tips_on = value
	if value:
		tutorial_seen = {}   # turning tips back on shows them again from the start
	save_game()


## Missions open only after every training puzzle has been finished once.
func all_puzzles_done() -> bool:
	for id in puzzle_order():
		if not is_puzzle_done(str(id)):
			return false
	return true


func reset_progress() -> void:
	play_sound("power_down")
	puzzles_done = {}
	best_stars = 0
	missions_done = {}
	mission_stars = {}
	tutorial_seen = {}
	lives = MAX_LIVES
	life_clock = 0.0
	stardust = 0
	save_game()


# ---- the player's astronaut

func has_profile() -> bool:
	return player_name.strip_edges() != ""


## "Commander Sam". Falls back to "Cadet" before a name has been chosen.
func display_name() -> String:
	var n: String = player_name.strip_edges()
	if n == "":
		return "Cadet"
	return (player_title + " " + n).strip_edges()


func set_profile(name_text: String, title: String, suit: int, patch: int) -> void:
	player_name = name_text.strip_edges().left(14)
	player_title = title
	avatar_suit = suit
	avatar_patch = patch
	save_game()
