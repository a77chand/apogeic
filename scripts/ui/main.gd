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
var tutorial_skipped := false   # "Skip tutorial" hides the guide for this game
var planned_builds: Array = []  # modules ordered this sol, sent with End sol
var chosen_priority := ""
var last_report: Array = []

@onready var background_art: TextureRect = $BackgroundArt
@onready var top_bar = $Margin/Layout/TopBar
@onready var meter_panel = $Margin/Layout/Body/LeftColumn/MeterPanel
@onready var alerts_panel = $Margin/Layout/Body/LeftColumn/AlertsPanel
@onready var report_panel = $ReportPanel
@onready var end_screen = $EndScreen
@onready var base_view = $Margin/Layout/Body/CenterColumn/BaseView
@onready var tutorial_panel = $Margin/Layout/Body/CenterColumn/TutorialPanel
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
	top_bar.tutorial_toggled.connect(_on_tutorial_toggled)
	tutorial_panel.skip_requested.connect(_on_tutorial_skipped)
	build_menu.build_requested.connect(plan_build)
	build_menu.clear_requested.connect(clear_plan)
	end_screen.restart_requested.connect(start_game)
	end_screen.switch_mode_requested.connect(func(): _on_mode_selected("mars" if scenario_id == "moon" else "moon"))
	start_game()


func start_game() -> void:
	sim = OutpostSim.new(data, scenario_id, tutorial_on)
	state = sim.new_game(randi())  # Godot picks a random seed at startup
	planned_builds = []
	tutorial_skipped = false
	chosen_priority = state.power_priority
	last_report = []
	report_panel.hide()
	end_screen.hide()
	background_art.texture = Art.background_texture(scenario_id)
	build_menu.setup(sim)
	refresh()


func end_sol() -> void:
	if state.status != "playing" or tutorial_block() != "":
		return
	var finished_sol: int = state.sol
	var result: Dictionary = sim.tick(state, {"build": planned_builds, "power_priority": chosen_priority})
	state = result.state
	last_report = result.report
	planned_builds = []
	refresh()
	if state.status == "playing":
		report_panel.show_report(state.day_word, finished_sol, last_report)
	else:
		report_panel.hide()
		end_screen.show_end(sim, state)  # win or loss: skip the report, show the debrief


## Redraws every UI piece from the current state.
func refresh() -> void:
	top_bar.show_state(state, chosen_priority, points_left(), tutorial_block())
	meter_panel.show_state(sim, state)
	alerts_panel.show_state(sim, state)
	base_view.show_state(sim, state, planned_builds)
	build_menu.show_state(sim, state, planned_builds)
	if tutorial_skipped:
		tutorial_panel.hide()
		build_menu.highlight("")
	else:
		tutorial_panel.show_state(sim, state, planned_builds)
		build_menu.highlight(tutorial_panel.goal_module(sim, state))


## Why End sol must wait for the tutorial goal, or "" if it may go ahead.
func tutorial_block() -> String:
	if tutorial_skipped:
		return ""
	return tutorial_panel.blocking_reason(sim, state, planned_builds)


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


func _on_tutorial_toggled(on: bool) -> void:
	tutorial_on = on
	start_game()


func _on_tutorial_skipped() -> void:
	tutorial_skipped = true
	refresh()


func _on_priority_selected(priority_id: String) -> void:
	chosen_priority = priority_id
	refresh()
