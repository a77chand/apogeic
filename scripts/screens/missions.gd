extends Control
## Choose a mission. 20 missions, each based on a real spaceflight. They unlock in order: finish a mission (reach the goal, or get close)
## to open the next one. Progress and best stars are saved in GameState.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

var _tip: Label = null


func _ready() -> void:
	_build_top_bar()
	_build_cards()
	_build_bottom()
	Tutorial.maybe_show(self, "missions")


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


## 20 missions as a grid of tiles (number, name, stars); the chosen tile's details show
## on the right with the real mission it is based on and the start button.
var _detail: VBoxContainer = null
var _tiles: Array = []


func _build_cards() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_place(grid, Vector2(20, 88), Vector2(770, 500))
	var ids: Array = GameState.mission_ids()
	var first_open: int = 0
	for i in range(ids.size()):
		var id: String = str(ids[i])
		grid.add_child(_tile(i, id))
		if GameState.is_mission_open(id):
			first_open = i
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(806, 88), Vector2(454, 500))
	_detail = UI.vbox(8)
	panel.add_child(_detail)
	_show(first_open)


func _tile(index: int, id: String) -> Button:
	var info: Dictionary = GameState.mission_info(id)
	var done: bool = GameState.is_mission_done(id)
	var open: bool = GameState.is_mission_open(id)
	var stars: int = int(GameState.mission_stars.get(id, 0))
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(146.0, 116.0)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var star_text: String = "★".repeat(stars) + "☆".repeat(3 - stars)
	b.text = "%02d\n%s\n%s" % [index + 1, str(info.get("name", id)), star_text if done else ("Open" if open else "Locked")]
	b.add_theme_font_size_override("font_size", 14)
	var edge: Color = UI.C_GREEN if done else (UI.C_CYAN if open else UI.C_DISABLED_BORDER)
	var fill: Color = Color(0.03, 0.07, 0.14, 0.92) if open or done else Color(0.03, 0.05, 0.09, 0.8)
	b.add_theme_stylebox_override("normal", UI.box(fill, Color(edge, 0.8), 6, 1, 10.0))
	b.add_theme_stylebox_override("hover", UI.box(fill.lightened(0.08), edge, 6, 2, 10.0))
	b.add_theme_stylebox_override("pressed", UI.box(fill.lightened(0.12), edge, 6, 3, 10.0))
	b.add_theme_color_override("font_color", UI.C_TEXT if open or done else UI.C_MUTED)
	b.pressed.connect(_show.bind(index))
	_tiles.append(b)
	return b


func _show(index: int) -> void:
	var id: String = str(GameState.mission_ids()[index])
	var info: Dictionary = GameState.mission_info(id)
	var done: bool = GameState.is_mission_done(id)
	var open: bool = GameState.is_mission_open(id)
	for i in range(_tiles.size()):
		var t: Button = _tiles[i]
		t.add_theme_constant_override("outline_size", 0)
		t.modulate = Color(1, 1, 1) if i == index else Color(0.82, 0.86, 0.92)
	UI.clear(_detail)
	var head: HBoxContainer = UI.hbox(8)
	_detail.add_child(head)
	var level_label: Label = UI.label(str(info.get("level_label", "Mission %d" % (index + 1))), 13, UI.C_MUTED)
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(level_label)
	var problem: String = str(info.get("main_problem", ""))
	if problem != "":
		var tag: PanelContainer = PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UI.box(Color(UI.C_ORANGE, 0.18), UI.C_ORANGE, 6, 1, 4.0))
		tag.add_child(UI.label(problem, 12, UI.C_ORANGE))
		head.add_child(tag)
	_detail.add_child(UI.label(str(info.get("name", id)), 26, UI.C_TEXT if open else UI.C_MUTED, true))
	_detail.add_child(UI.based_on_tag(info, 420.0))
	var b: Dictionary = info.get("based_on", {})
	var story: Label = UI.label(str(b.get("story", info.get("goal_text", ""))), 13, UI.C_TEXT, true)
	story.custom_minimum_size = Vector2(420.0, 0.0)
	_detail.add_child(story)
	if b.has("lesson"):
		var lesson: Label = UI.label("Lesson: " + str(b.get("lesson", "")), 13, UI.C_ACCENT, true)
		lesson.custom_minimum_size = Vector2(420.0, 0.0)
		_detail.add_child(lesson)
	var row: HBoxContainer = UI.hbox(10)
	_detail.add_child(row)
	var rocket: Dictionary = info.get("rocket", {})
	var pic: Control = UI.picture("res://art/modules/%s.png" % str(rocket.get("kind", "rocket_small")), Vector2(40, 110), "rocket")
	if not open:
		pic.modulate = Color(1, 1, 1, 0.4)
	row.add_child(pic)
	var right: VBoxContainer = UI.vbox(4)
	row.add_child(right)
	right.add_child(UI.label(str(rocket.get("name", "")), 13, UI.C_ACCENT))
	var goal: Label = UI.label(str(info.get("goal_text", "")), 12, UI.C_MUTED, true)
	goal.custom_minimum_size = Vector2(360.0, 0.0)
	right.add_child(goal)
	var limits: Dictionary = info.get("limits", {})
	right.add_child(UI.label("Up to %.1f kg  |  %s  |  launch by day %d" % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(limits.get("deadline_day", 0))], 13, UI.C_YELLOW, true))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)
	if open:
		_detail.add_child(UI.button("Play again" if done else "Start mission", _on_start.bind(id), 420.0, not done))
	else:
		var before: Dictionary = GameState.mission_info(str(GameState.mission_ids()[maxi(0, index - 1)]))
		var locked: Button = UI.button("Finish %s first" % str(before.get("name", "the one before")), _on_locked.bind(id), 420.0, false)
		UI.look_locked(locked)
		_detail.add_child(locked)


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	_tip = UI.label("20 missions, each based on a real spaceflight. Reach the goal, or get close, to unlock the next.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 600), Vector2(160, 52))


func _on_start(id: String) -> void:
	GameState.set_mission(id)
	GameState.go("briefing")


func _on_locked(id: String) -> void:
	var index: int = GameState.mission_ids().find(id)
	var before: Dictionary = GameState.mission_info(str(GameState.mission_ids()[maxi(0, index - 1)]))
	_tip.text = "Finish %s first. Reaching the goal, or getting close, counts." % str(before.get("name", "the mission before"))


func _on_back() -> void:
	GameState.go("title")
