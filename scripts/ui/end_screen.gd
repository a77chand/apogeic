## Shown when the mission ends. A win shows a summary; a loss shows the cause
## chain from the sim's debrief as linked steps, plus a tip.
extends Control

signal restart_requested
signal switch_mode_requested

const UiStyle = preload("res://scripts/ui/ui_style.gd")
const TrendArrow = preload("res://scripts/ui/trend_arrow.gd")

const WIN_COLOR := Color(0.45, 0.9, 0.5)
const LOSE_COLOR := Color(1, 0.45, 0.4)

@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var chain_title: Label = $Center/Panel/Margin/VBox/ChainTitle
@onready var chain_list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/Chain
@onready var tip_label: Label = $Center/Panel/Margin/VBox/Tip
@onready var stats_label: Label = $Center/Panel/Margin/VBox/Stats
@onready var restart_button: Button = $Center/Panel/Margin/VBox/Buttons/RestartButton
@onready var switch_button: Button = $Center/Panel/Margin/VBox/Buttons/SwitchButton


func _ready() -> void:
	restart_button.pressed.connect(func(): restart_requested.emit())
	switch_button.pressed.connect(func(): switch_mode_requested.emit())
	hide()


func show_end(sim, state: Dictionary) -> void:
	for child in chain_list.get_children():
		chain_list.remove_child(child)
		child.queue_free()
	var word: String = state.day_word
	var other_place := "Mars" if state.scenario == "moon" else "the Moon"
	switch_button.text = "Try %s" % other_place
	stats_label.text = _stats(sim, state)

	if state.status == "won":
		panel.add_theme_stylebox_override("panel", UiStyle.solid_panel(WIN_COLOR))
		title.text = "Mission complete!"
		title.add_theme_color_override("font_color", WIN_COLOR)
		subtitle.text = "Your crew survived all %d %ss on %s." % [state.max_sols, word.to_lower(), sim.scenario.name]
		chain_title.hide()
		tip_label.text = "Every base is different. Can you win with a healthier crew, or less radiation? Try %s next." % other_place
	else:
		var failure: Dictionary = state.failure
		panel.add_theme_stylebox_override("panel", UiStyle.solid_panel(LOSE_COLOR))
		title.text = "Mission failed"
		title.add_theme_color_override("font_color", LOSE_COLOR)
		subtitle.text = "The mission ended on %s %d of %d." % [word, failure.sol, state.max_sols]
		chain_title.show()
		var steps: Array = failure.chain
		for i in steps.size():
			_add_step(steps[i], i == steps.size() - 1)
			if i < steps.size() - 1:
				_add_arrow()
		tip_label.text = "Tip: " + failure.tip
	show()
	restart_button.grab_focus()


## One box in the cause chain. The last one (the failure) is drawn in red.
func _add_step(text: String, is_last: bool) -> void:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.12, 0.12) if is_last else Color(0.18, 0.2, 0.26)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	chain_list.add_child(box)


## A small downward arrow between steps: "this led to...".
func _add_arrow() -> void:
	var arrow := TrendArrow.new()
	arrow.custom_minimum_size = Vector2(18, 14)
	arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chain_list.add_child(arrow)
	arrow.set_trend(-1.0, false)  # down, colored red


func _stats(sim, state: Dictionary) -> String:
	var built := 0
	for id in state.modules:
		built += state.modules[id]
	return "Crew health: %d / %d    Radiation: %d / %d    Modules: %d" % [
		roundi(state.meters.health), roundi(sim.meter_max(state, "health")),
		roundi(state.meters.radiation), roundi(sim.meter_max(state, "radiation")), built]
