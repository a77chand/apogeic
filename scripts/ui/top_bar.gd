## The strip across the top: Moon/Mars toggle, sol counter, build points,
## power priority, Restart and End sol. It sends signals; main.gd decides what to do.
extends PanelContainer

signal mode_selected(scenario_id: String)
signal priority_selected(priority_id: String)
signal tutorial_toggled(on: bool)
signal restart_pressed
signal end_sol_pressed

@onready var moon_button: Button = $Margin/HBox/MoonButton
@onready var mars_button: Button = $Margin/HBox/MarsButton
@onready var tutorial_check: CheckBox = $Margin/HBox/TutorialCheck
@onready var sol_label: Label = $Margin/HBox/SolLabel
@onready var points_label: Label = $Margin/HBox/PointsLabel
@onready var priority_option: OptionButton = $Margin/HBox/PriorityOption
@onready var restart_button: Button = $Margin/HBox/RestartButton
@onready var end_sol_button: Button = $Margin/HBox/EndSolButton


func _ready() -> void:
	# A ButtonGroup makes Moon and Mars behave like radio buttons: only one is pressed.
	var group := ButtonGroup.new()
	moon_button.button_group = group
	mars_button.button_group = group
	moon_button.pressed.connect(func(): mode_selected.emit("moon"))
	mars_button.pressed.connect(func(): mode_selected.emit("mars"))
	restart_button.pressed.connect(func(): restart_pressed.emit())
	end_sol_button.pressed.connect(func(): end_sol_pressed.emit())
	priority_option.item_selected.connect(_on_priority_item_selected)
	tutorial_check.toggled.connect(func(on): tutorial_toggled.emit(on))
	# Make End sol stand out: it's the main button of the game.
	var accent := StyleBoxFlat.new()
	accent.bg_color = Color(0.85, 0.45, 0.2)
	accent.set_corner_radius_all(6)
	end_sol_button.add_theme_stylebox_override("normal", accent)
	var accent_hover := accent.duplicate()
	accent_hover.bg_color = Color(0.95, 0.55, 0.3)
	end_sol_button.add_theme_stylebox_override("hover", accent_hover)


## Fills the priority dropdown from modules.json "power_priorities".
func set_priorities(priorities: Dictionary) -> void:
	priority_option.clear()
	for id in priorities:
		priority_option.add_item(priorities[id].name)
		priority_option.set_item_metadata(priority_option.item_count - 1, id)


## `blocked_reason` is non-empty when End sol must wait (the tutorial goal).
func show_state(state: Dictionary, chosen_priority: String, points_left: int, blocked_reason: String = "") -> void:
	moon_button.set_pressed_no_signal(state.scenario == "moon")
	mars_button.set_pressed_no_signal(state.scenario == "mars")
	sol_label.text = "%s %d / %d" % [state.day_word, state.sol, state.max_sols]
	points_label.text = "Build points: %d" % points_left
	end_sol_button.text = "End %s" % str(state.day_word).to_lower()
	end_sol_button.disabled = state.status != "playing" or blocked_reason != ""
	end_sol_button.tooltip_text = blocked_reason
	tutorial_check.set_pressed_no_signal(state.tutorial)
	for i in priority_option.item_count:
		if priority_option.get_item_metadata(i) == chosen_priority:
			priority_option.select(i)


func _on_priority_item_selected(index: int) -> void:
	priority_selected.emit(priority_option.get_item_metadata(index))
