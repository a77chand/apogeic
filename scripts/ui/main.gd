## Root of the game. Owns the simulation and the current state, and connects the
## UI pieces to it. UI pieces never change the state themselves: they emit
## signals, and this script turns those into actions for sim.tick().
extends Control

const GameData = preload("res://scripts/sim/game_data.gd")
const OutpostSim = preload("res://scripts/sim/outpost_sim.gd")
const Art = preload("res://scripts/ui/art.gd")

var data: Dictionary
var sim                       # the OutpostSim for the current scenario
var state: Dictionary         # the current game state (see outpost_sim.gd new_game)
var scenario_id := "mars"
var tutorial_on := true
var planned_builds: Array = []  # modules ordered this sol, sent with End sol
var chosen_priority := ""
var last_report: Array = []

@onready var background_art: TextureRect = $BackgroundArt
@onready var top_bar = $Margin/Layout/TopBar
@onready var meter_panel = $Margin/Layout/Body/MeterPanel
@onready var base_view = $Margin/Layout/Body/BaseView
@onready var build_menu = $Margin/Layout/Body/BuildMenu
@onready var error_label: Label = $ErrorLabel


func _ready() -> void:
	# Slightly bigger text everywhere, for young players. Children inherit this theme.
	var t := Theme.new()
	t.default_font_size = 17
	theme = t

	data = GameData.load_all()
	if not data.errors.is_empty():
		error_label.text = "Data problem:\n" + "\n".join(data.errors)
		error_label.show()
		return
	top_bar.set_priorities(data.modules.power_priorities)
	top_bar.mode_selected.connect(_on_mode_selected)
	top_bar.priority_selected.connect(_on_priority_selected)
	top_bar.restart_pressed.connect(start_game)
	top_bar.end_sol_pressed.connect(end_sol)
	build_menu.build_requested.connect(plan_build)
	build_menu.clear_requested.connect(clear_plan)
	start_game()


func start_game() -> void:
	sim = OutpostSim.new(data, scenario_id, tutorial_on)
	state = sim.new_game(randi())  # Godot picks a random seed at startup
	planned_builds = []
	chosen_priority = state.power_priority
	last_report = []
	background_art.texture = Art.background_texture(scenario_id)
	build_menu.setup(sim)
	refresh()


func end_sol() -> void:
	if state.status != "playing":
		return
	var result: Dictionary = sim.tick(state, {"build": planned_builds, "power_priority": chosen_priority})
	state = result.state
	last_report = result.report
	planned_builds = []
	refresh()


## Redraws every UI piece from the current state.
func refresh() -> void:
	top_bar.show_state(state, chosen_priority, points_left())
	meter_panel.show_state(sim, state)
	base_view.show_state(sim, state, planned_builds)
	build_menu.show_state(sim, state, planned_builds)


## Adds a module to this sol's plan if the sim says it's allowed.
func plan_build(module_id: String) -> void:
	if sim.can_build(state, module_id, planned_builds) == "":
		planned_builds.append(module_id)
		refresh()


func clear_plan() -> void:
	planned_builds = []
	refresh()


## Build points after paying for this sol's planned builds.
func points_left() -> int:
	var left: int = state.build_points
	for id in planned_builds:
		left -= sim.build_cost(id)
	return left


func _on_mode_selected(new_scenario_id: String) -> void:
	if new_scenario_id != scenario_id:
		scenario_id = new_scenario_id
		start_game()


func _on_priority_selected(priority_id: String) -> void:
	chosen_priority = priority_id
	refresh()
