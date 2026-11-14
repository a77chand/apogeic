
extends RefCounted

const UI = preload("res://scripts/ui/ui.gd")


static func top_bar(title: String, pills: Array) -> Control:
	var bar: PanelContainer = UI.panel(UI.C_CYAN, 12.0)
	bar.custom_minimum_size = Vector2(0, 72)

	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)

	var game_name: Label = UI.label("SPACE MISSION DESIGNER", 18, UI.C_CYAN)
	row.add_child(game_name)

	var screen_title: Label = UI.label(title, 20, UI.C_TEXT)
	screen_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(screen_title)

	for pill_text in pills:
		var pill: Label = UI.label(str(pill_text), 13, UI.C_YELLOW)
		row.add_child(pill)

	return bar


static func set_pill(bar: Control, index: int, text: String) -> void:
	var row: HBoxContainer = bar.get_child(0) as HBoxContainer
	var pill_index: int = index + 2

	if pill_index < row.get_child_count():
		var pill: Label = row.get_child(pill_index) as Label
		pill.text = text


static func tip_bar(text: String) -> Control:
	var bar: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	bar.custom_minimum_size = Vector2(0, 58)

	var row: HBoxContainer = UI.hbox(12)
	bar.add_child(row)

	var tip: Label = UI.label(text, 14, UI.C_TEXT, true)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tip)

	var placeholder: Label = UI.label("PLACEHOLDER NUMBERS", 11, UI.C_YELLOW)
	row.add_child(placeholder)

	return bar


static func set_tip(bar: Control, text: String) -> void:
	var row: HBoxContainer = bar.get_child(0) as HBoxContainer
	var tip: Label = row.get_child(0) as Label
	tip.text = text
