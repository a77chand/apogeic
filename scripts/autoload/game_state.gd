extends Node
## Autoload named GameState. Holds the loaded data and the state of the current
## play-through. Screens read and write here. Rules live in sim.gd, not here.

signal design_changed

const Data = preload("res://scripts/core/data.gd")
const Sim = preload("res://scripts/core/sim.gd")
const SAVE_PATH: String = "user://save.json"

# ---- loaded once from data/*.json
var parts: Dictionary = {}
var level: Dictionary = {}
var puzzles: Dictionary = {}
var events: Array = []

# ---- progress that is saved
var puzzles_done: Dictionary = {}   # puzzle id -> true
var best_stars: int = 0

# ---- the current mission attempt (reset by reset_mission)
var design: Dictionary = {}         # slot id -> part id or ""
var sched: Dictionary = {}          # see Sim.new_schedule()
var launch_eval: Dictionary = {}    # evaluate() frozen at launch
var launch_results: Array = []      # requirement results frozen at launch
var ops: Dictionary = {}            # see Sim.new_ops_state()
var log_lines: Array = []           # event log lines for the report
var events_seen: Dictionary = {}    # event id -> true

var router: Node = null             # set by main.gd


func _ready() -> void:
	parts = Data.load_parts()
	level = Data.load_level1()
	puzzles = Data.load_puzzles()
	events = Data.load_events()
	load_save()
	reset_mission()


## Change screen. Screen ids are listed in main.gd.
func go(screen_id: String) -> void:
	if router != null:
		router.call("go", screen_id)


func reset_mission() -> void:
	design = Sim.new_design(level)
	sched = Sim.new_schedule()
	launch_eval = {}
	launch_results = []
	ops = {}
	log_lines = []
	events_seen = {}
	design_changed.emit()


## A new attempt that keeps the parts already chosen. Used by "Retry with changes".
func retry_mission() -> void:
	sched = Sim.new_schedule()
	launch_eval = {}
	launch_results = []
	ops = {}
	log_lines = []
	events_seen = {}
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
	file.store_string(JSON.stringify({"puzzles_done": puzzles_done, "best_stars": best_stars}))
	file.close()


func load_save() -> void:
	puzzles_done = {}
	best_stars = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Dictionary = Data.load_dict(SAVE_PATH)
	var done: Variant = data.get("puzzles_done", {})
	if typeof(done) == TYPE_DICTIONARY:
		puzzles_done = done
	best_stars = int(data.get("best_stars", 0))


func reset_progress() -> void:
	puzzles_done = {}
	best_stars = 0
	save_game()
