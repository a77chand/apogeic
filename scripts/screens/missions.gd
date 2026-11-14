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
	col.add_child(UI.label("Mission %d" % (index + 1), 14, UI.C_MUTED))
	var name_color: Color = UI.C_TEXT
	if not open:
		name_color = UI.C_MUTED
	col.add_child(UI.label(str(info.get("name", id)), 26, name_color, true))
	var goal: Label = UI.label(str(info.get("goal_text", "")), 15, UI.C_TEXT, true)
	goal.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(goal)
	var teaches: Label = UI.label("What is new: " + str(info.get("blurb", "")), 13, UI.C_CYAN, true)
	teaches.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(teaches)
	var limits: Dictionary = info.get("limits", {})
	var facts: Label = UI.label("Up to %.1f kg  |  %s  |  launch by day %d" % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(limits.get("deadline_day", 0))], 13, UI.C_MUTED, true)
	facts.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(facts)
	var learn: Label = UI.label(str(info.get("teaches", "")), 13, UI.C_MUTED, true)
	learn.custom_minimum_size = Vector2(364.0, 0.0)
	col.add_child(learn)
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
	_tip = UI.label("Reach the goal, or get close, to unlock the next mission.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 590), Vector2(160, 52))


func _on_start(id: String) -> void:
	GameState.set_mission(id)
	GameState.go("briefing")


func _on_locked(id: String) -> void:
	var index: int = GameState.mission_ids().find(id)
	var before: Dictionary = GameState.mission_info(str(GameState.mission_ids()[maxi(0, index - 1)]))
	_tip.text = "Finish %s first. Reaching the goal, or getting close, counts." % str(before.get("name", "the mission before"))


func _on_back() -> void:
	GameState.go("title")
