extends Control
## Choose a mission. They unlock in order: finish a mission (reach the goal, or get close)
## to open the next one. Progress and best stars are saved in GameState.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")

var _tip: Label = null


func _ready() -> void:
	_build_top_bar()
	_build_cards()
	_build_bottom()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Choose your mission", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(14.0, 14.0)


func _build_cards() -> void:
	var row: HBoxContainer = UI.hbox(20)
	_place(row, Vector2(20, 92), Vector2(1240, 480))
	var ids: Array = GameState.mission_ids()
	for i in range(ids.size()):
		var id: String = str(ids[i])
		row.add_child(_card(i, id))


func _card(index: int, id: String) -> Control:
	var info: Dictionary = GameState.mission_info(id)
	var done: bool = GameState.is_mission_done(id)
	var open: bool = GameState.is_mission_open(id)
	var border: Color = UI.C_DISABLED_BORDER
	if done:
		border = UI.C_GREEN
	elif open:
		border = UI.C_CYAN
	var panel: PanelContainer = UI.panel(border, 16.0)
	panel.custom_minimum_size = Vector2(400.0, 480.0)
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(8)
	col.add_child(head)
	var level_label: Label = UI.label(str(info.get("level_label", "Mission %d" % (index + 1))), 14, UI.C_MUTED)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	var problem: String = str(info.get("main_problem", ""))
	if problem != "":
		var tag: PanelContainer = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UI.box(Color(UI.C_ORANGE, 0.18), UI.C_ORANGE, 6, 1, 4.0))
		tag.add_child(UI.label("Main problem: " + problem, 12, UI.C_ORANGE))
		head.add_child(tag)
	var name_color: Color = UI.C_TEXT
	if not open:
		name_color = UI.C_MUTED
	col.add_child(UI.label(str(info.get("name", id)), 26, name_color, true))
	var goal: Label = UI.label(str(info.get("goal_text", "")), 14, UI.C_TEXT, true)
	goal.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(goal)
	# the rocket picture beside what makes this mission different
	var row: HBoxContainer = UI.hbox(10)
	col.add_child(row)
	var rocket: Dictionary = info.get("rocket", {})
	var pic: Control = UI.picture("res://art/modules/%s.png" % str(rocket.get("kind", "rocket_small")), Vector2(46, 140), "rocket")
	pic.tooltip_text = str(rocket.get("why", ""))
	if not open:
		pic.modulate = Color(1, 1, 1, 0.4)
	row.add_child(pic)
	var right: VBoxContainer = UI.vbox(4)
	row.add_child(right)
	right.add_child(UI.label(str(rocket.get("name", "")), 13, UI.C_ACCENT))
	right.add_child(UI.bullets(info.get("differences", []), 12, UI.C_TEXT if open else UI.C_MUTED, 300.0, UI.C_ORANGE))
	var limits: Dictionary = info.get("limits", {})
	var facts: Label = UI.label("Up to %.1f kg  |  %s  |  launch by day %d" % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(limits.get("deadline_day", 0))], 13, UI.C_YELLOW, true)
	facts.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(facts)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var status: String = "Locked"
	var status_color: Color = UI.C_MUTED
	if done:
		status = "Done: best %d of 3 stars" % int(GameState.mission_stars.get(id, 0))
		status_color = UI.C_GREEN
	elif open:
		status = "Ready to play"
		status_color = UI.C_CYAN
	else:
		var before: Dictionary = GameState.mission_info(str(GameState.mission_ids()[maxi(0, index - 1)]))
		status = "Finish %s first" % str(before.get("name", "the mission before"))
	col.add_child(UI.label(status, 16, status_color, true))
	if open:
		var label: String = "Start mission"
		if done:
			label = "Play again"
		col.add_child(UI.button(label, _on_start.bind(id), 364.0, not done))
	else:
		var locked: Button = UI.button("Locked", _on_locked.bind(id), 364.0, false)
		UI.look_locked(locked)
		col.add_child(locked)
	return panel


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	_tip = UI.label("Each mission is a level: a new main problem and a new rocket. Reach the goal, or get close, to unlock the next.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 602), Vector2(160, 52))


func _on_start(id: String) -> void:
	GameState.set_mission(id)
	GameState.go("briefing")


func _on_locked(id: String) -> void:
	var index: int = GameState.mission_ids().find(id)
	var before: Dictionary = GameState.mission_info(str(GameState.mission_ids()[maxi(0, index - 1)]))
	_tip.text = "Finish %s first. Reaching the goal, or getting close, counts." % str(before.get("name", "the mission before"))


func _on_back() -> void:
	GameState.go("title")
