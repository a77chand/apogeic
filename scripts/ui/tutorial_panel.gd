## The tutorial box for sols 1 to 5. Steps come from data/tutorial.json.
## It shows what to do, says when the goal is planned, and tells main.gd
## whether End sol should wait for the goal.
extends PanelContainer

signal skip_requested

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const ACCENT := Color(0.95, 0.6, 0.25)
const DONE_COLOR := Color(0.45, 0.9, 0.5)

@onready var title: Label = $Margin/VBox/Header/Title
@onready var body: Label = $Margin/VBox/Body
@onready var goal_label: Label = $Margin/VBox/Goal
@onready var skip_button: Button = $Margin/VBox/Header/SkipButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.solid_panel(ACCENT))
	skip_button.pressed.connect(func(): skip_requested.emit())
	hide()


## The tutorial step for the current sol, or {} if there is none.
func current_step(sim, state: Dictionary) -> Dictionary:
	if not state.tutorial or sim.tutorial.is_empty():
		return {}
	for step in sim.tutorial.steps:
		if int(step.sol) == state.sol:
			return step
	return {}


## Module id the player should build this sol, or "".
func goal_module(sim, state: Dictionary) -> String:
	return str(current_step(sim, state).get("goal_build", ""))


## A reason End sol should wait, or "" if the player may end the sol.
## We only wait while the goal can still be afforded, so nobody gets stuck.
func blocking_reason(sim, state: Dictionary, planned: Array) -> String:
	var goal := goal_module(sim, state)
	if goal == "" or planned.has(goal) or state.status != "playing":
		return ""
	if sim.can_build(state, goal, planned) != "":
		return ""
	return "Tutorial: build a %s first" % sim.module_name(goal)


func show_state(sim, state: Dictionary, planned: Array) -> void:
	var step := current_step(sim, state)
	if step.is_empty():
		hide()
		return
	var day := str(state.day_word).to_lower()
	title.text = "%s %d: %s" % [state.day_word, state.sol, step.title]
	var text: String = step.text
	# Some steps change their message if the player skipped an earlier goal.
	var needs := str(step.get("needs_module", ""))
	if needs != "" and state.modules[needs] == 0:
		text = step.text_if_missing
	body.text = text.replace("{day}", day)

	var goal := str(step.get("goal_build", ""))
	if goal == "":
		goal_label.hide()
	else:
		goal_label.show()
		if planned.has(goal):
			goal_label.text = "Done! %s planned. Now press End %s." % [sim.module_name(goal), day]
			goal_label.add_theme_color_override("font_color", DONE_COLOR)
		else:
			goal_label.text = "Goal: build a %s (highlighted on the right)." % sim.module_name(goal)
			goal_label.add_theme_color_override("font_color", ACCENT)
	show()
