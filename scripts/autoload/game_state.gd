extends Node
## Autoload named GameState. Holds the loaded data and the state of the current
## play-through. Screens read and write here. Rules live in sim.gd, not here.

signal design_changed

const Data = preload("res://scripts/core/data.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Craft = preload("res://scripts/core/craft.gd")
const SAVE_PATH: String = "user://save.json"

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
var tutorial_seen: Dictionary = {}  # screen id -> true, so each tip shows once
var tutorial_open: bool = false     # true while a tip box is on screen (clocks wait)
var muted: bool = false             # sound on/off, saved
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
	save_game()


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
	var slots: Dictionary = Data.event_slots(events)
	for key in slots.keys():
		var ids: Array = slots[key]
		event_picks[str(key)] = str(ids[rng.randi_range(0, ids.size() - 1)])


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


func is_mission_done(id: String) -> bool:
	return missions_done.has(id)


## A mission is open when it is the first one, or the one before it was finished
## (reached the goal or got close: a failed attempt does not unlock the next one).
func is_mission_open(id: String) -> bool:
	var index: int = Data.MISSIONS.find(id)
	if index <= 0:
		return index == 0
	return is_mission_done(str(Data.MISSIONS[index - 1]))


## Called when the mission ends. grade is "success", "partial" or "failed".
func record_mission_result(grade: String, stars: int) -> void:
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
			"player_name": player_name, "player_title": player_title, "avatar_suit": avatar_suit, "avatar_patch": avatar_patch}))
	file.close()


func load_save() -> void:
	puzzles_done = {}
	best_stars = 0
	missions_done = {}
	mission_stars = {}
	tutorial_seen = {}
	muted = false
	player_name = ""
	player_title = "Commander"
	avatar_suit = 0
	avatar_patch = 0
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
	var seen: Variant = data.get("tutorial_seen", {})
	if typeof(seen) == TYPE_DICTIONARY:
		tutorial_seen = seen


func reset_progress() -> void:
	puzzles_done = {}
	best_stars = 0
	missions_done = {}
	mission_stars = {}
	tutorial_seen = {}
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
