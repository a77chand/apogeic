extends RefCounted
## The shared frame: a top bar and a tip bar, so every screen looks the same.
## Use it through a preload:  const Chrome = preload("res://scripts/ui/chrome.gd")
##
##   var bar: Control = Chrome.top_bar("Puzzle 2: Power", ["Step 2 of 4"])
##   add_child(bar)
##   Chrome.set_pill(bar, 0, "Step 3 of 4")
##   var tip: Control = Chrome.tip_bar("Drag the sliders.")
##   add_child(tip)
##   Chrome.set_tip(tip, "New tip")
## Screens place their content between y = 84 and y = 650.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")


## A 72 px bar across the top. Game name left, title centre, one pill per entry in pills on the right.
static func top_bar(title: String, pills: Array) -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	bar.position = Vector2(0.0, 0.0)
	bar.custom_minimum_size = Vector2(1280.0, 72.0)
	bar.size = Vector2(1280.0, 72.0)
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	var left: HBoxContainer = UI.hbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Player.badge(44.0))
	row.add_child(left)
	var title_label: Label = UI.label(title, 28)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title_label)
	var right: HBoxContainer = UI.hbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right)
	var labels: Array = []
	for item in pills:
		var pill: PanelContainer = PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UI.box(UI.C_PANEL, UI.C_CYAN, 14, 2, 8.0))
		var text: Label = UI.label(str(item), 15, UI.C_CYAN)
		pill.add_child(text)
		right.add_child(pill)
		labels.append(text)
	bar.set_meta("pills", labels)
	return bar


static func set_pill(bar: Control, index: int, text: String) -> void:
	var labels: Array = bar.get_meta("pills", [])
	if index < 0 or index >= labels.size():
		return
	var label: Label = labels[index]
	label.text = text


## A 58 px bar across the bottom with one line of tip text and a PLACEHOLDER NUMBERS tag.
static func tip_bar(text: String) -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	bar.position = Vector2(0.0, 662.0)
	bar.custom_minimum_size = Vector2(1280.0, 58.0)
	bar.size = Vector2(1280.0, 58.0)
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	var tip: Label = UI.label(text, 15, UI.C_TEXT)
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.clip_text = true
	row.add_child(tip)
	var tag: Label = UI.label("PLACEHOLDER NUMBERS", 12, UI.C_YELLOW)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	bar.set_meta("tip", tip)
	return bar


static func set_tip(bar: Control, text: String) -> void:
	var tip: Label = bar.get_meta("tip", null)
	if tip != null:
		tip.text = text
