extends Control
## Briefing: the goal, the concept chips (locked ones say why), and what must be hit.
## Chips do not change the game in Level 1; they show the reasoning.

const UI = preload("res://scripts/ui/ui.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

var _tip: Label = null


func _ready() -> void:
	_build_top_bar()
	_build_mission()
	_build_concept()
	_build_requirements()
	_build_bottom()
	Tutorial.maybe_show(self, "briefing")


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Briefing", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)


func _build_mission() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(400, 480))
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("The mission", 20))
	col.add_child(UI.label(str(GameState.level.get("name", "")), 24, UI.C_CYAN))
	var pic: Control = UI.picture("res://art/modules/cubesat_3u.png", Vector2(360, 120), "CubeSat")
	col.add_child(pic)
	var goal: Label = UI.label(str(GameState.level.get("goal_text", "")), 15, UI.C_TEXT, true)
	goal.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(goal)
	var limits: Dictionary = GameState.level.get("limits", {})
	var words: String = "Limits: at most %.1f kg, a budget of %s, and launch by day %d." % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(float(limits.get("deadline_day", 0.0)))]
	var limit_label: Label = UI.label(words, 15, UI.C_YELLOW, true)
	limit_label.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(limit_label)


func _build_concept() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(436, 88), Vector2(420, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Your concept", 20))
	var chips: Array = GameState.level.get("concept_chips", [])
	var groups: Array = []
	for item in chips:
		var chip: Dictionary = item
		var group: String = str(chip.get("group", ""))
		if not groups.has(group):
			groups.append(group)
	for group_name in groups:
		col.add_child(UI.label(str(group_name), 14, UI.C_MUTED))
		var row: HFlowContainer = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.custom_minimum_size = Vector2(380.0, 0.0)
		col.add_child(row)
		for item in chips:
			var chip: Dictionary = item
			if str(chip.get("group", "")) != str(group_name):
				continue
			row.add_child(_chip(chip))


func _chip(chip: Dictionary) -> Button:
	var chosen: bool = str(chip.get("state", "")) == "chosen"
	var label: String = str(chip.get("label", ""))
	var b: Button = UI.button(label, Callable(), 10.0, false)
	b.custom_minimum_size = Vector2(0.0, 40.0)
	if chosen:
		b.add_theme_stylebox_override("normal", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 2, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 2, 8.0))
	else:
		b.text = label + " (locked)"
		b.add_theme_stylebox_override("normal", UI.box(UI.C_DISABLED, UI.C_DISABLED_BORDER, 16, 2, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.C_DISABLED, UI.C_DISABLED_BORDER, 16, 2, 8.0))
		b.add_theme_color_override("font_color", UI.C_MUTED)
		b.add_theme_color_override("font_hover_color", UI.C_MUTED)
		b.pressed.connect(_on_locked_chip.bind(label, str(chip.get("why", ""))))
	return b


func _build_requirements() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(872, 88), Vector2(388, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("You must hit", 20))
	var list: Array = GameState.level.get("requirements", [])
	for item in list:
		var r: Dictionary = item
		var text: Label = UI.label("%s  %s" % [str(r.get("id", "")), str(r.get("text", ""))], 15, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(350.0, 0.0)
		col.add_child(text)


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	_tip = UI.label("Click a locked choice to see why it is locked.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 590), Vector2(160, 52))
	_place(UI.button("Start building", _on_start, 260.0, true), Vector2(1000, 590), Vector2(260, 52))


func _on_locked_chip(label: String, why: String) -> void:
	_tip.text = "%s is locked: %s" % [label, why]


func _on_start() -> void:
	GameState.go("workshop")  # do not reset here: Retry must keep the parts


func _on_back() -> void:
	GameState.go("ladder")
