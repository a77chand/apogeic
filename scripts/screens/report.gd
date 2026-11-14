extends Control
## Report: stars, numbers, and the plain-language cause chain.
## Reads only from GameState and recomputes everything with Sim (spec 12.13).

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

const STAR_ON: Color = Color(0.95, 0.78, 0.26)
const STAR_OFF: Color = Color(0.35, 0.4, 0.5)


func _ready() -> void:
	if GameState.ops.is_empty():
		_build_empty()
		return
	var score: Dictionary = Sim.score_mission(GameState.level, GameState.ops, GameState.launch_results)
	var causes: Array = Sim.build_causes(GameState.launch_eval, GameState.launch_results, GameState.ops)
	_build_top_bar(str(score.get("grade", "failed")))
	_build_stars(score)
	_build_causes(causes)
	_build_log()
	_build_compare()
	_build_buttons()
	GameState.play_sound("chime" if int(score.get("stars", 0)) > 0 else "fail")
	Tutorial.maybe_show(self, "report")


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_empty() -> void:
	var centre: CenterContainer = CenterContainer.new()
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel()
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(14)
	panel.add_child(col)
	col.add_child(UI.label("No mission flown yet", 28))
	col.add_child(UI.button("Back to title", _on_title, 240.0, true))


func _build_top_bar(grade: String) -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title_text: String = "Mission failed"
	var color: Color = UI.C_RED
	if grade == "success":
		title_text = "Mission success"
		color = UI.C_GREEN
	elif grade == "partial":
		title_text = "Partial success"
		color = UI.C_YELLOW
	var title: Label = UI.label(title_text, 30, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)


## A star: the art file if it exists, otherwise a shape drawn with code.
func _star(lit: bool) -> Control:
	var tint: Color = STAR_ON
	if not lit:
		tint = STAR_OFF
	var path: String = "res://art/icons/icon_star.png"
	if ResourceLoader.exists(path):
		var pic: Control = UI.picture(path, Vector2(54, 54))
		pic.modulate = tint
		return pic
	var shape: Control = Control.new()
	shape.custom_minimum_size = Vector2(54.0, 54.0)
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.draw.connect(_draw_star.bind(shape, tint))
	return shape


func _draw_star(shape: Control, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var centre: Vector2 = Vector2(27.0, 29.0)
	for i in range(10):
		var radius: float = 25.0
		if i % 2 == 1:
			radius = 10.5
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	shape.draw_colored_polygon(points, tint)


func _build_stars(score: Dictionary) -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(400, 330))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Your stars", 20))
	var rows: Array = [
		[bool(score.get("star_goal", false)), "Goal reached"],
		[bool(score.get("star_checks", false)), "All checks passed"],
		[bool(score.get("star_budget", false)), "Finished with 10% in reserve"],
	]
	for item in rows:
		var row_data: Array = item
		var row: HBoxContainer = UI.hbox(10)
		row.add_child(_star(bool(row_data[0])))
		var label: Label = UI.label(str(row_data[1]), 16)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		col.add_child(row)
	var cfg: Dictionary = GameState.level.get("ops", {})
	var ops: Dictionary = GameState.ops
	col.add_child(UI.label("Delivered: %d of %d MB" % [int(round(float(ops.get("delivered_mb", 0.0)))), int(float(cfg.get("goal_mb", 0.0)))], 14))
	col.add_child(UI.label("Lost: %d MB   Money left: %s" % [int(round(float(ops.get("lost_mb", 0.0)))), UI.money(float(ops.get("money_k", 0.0)))], 14))
	col.add_child(UI.label("Weeks flown: %d of %d" % [int(ops.get("week", 0)), int(cfg.get("weeks", 12))], 14))


func _build_causes(causes: Array) -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(436, 88), Vector2(824, 330))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Why it happened", 20))
	var shown: int = mini(3, causes.size())
	for i in range(shown):
		var c: Dictionary = causes[i]
		var card: PanelContainer = UI.panel(UI.C_DISABLED_BORDER, 8.0)
		var inner: VBoxContainer = UI.vbox(2)
		card.add_child(inner)
		var line: Label = UI.label("%s   ->   %s" % [str(c.get("cause", "")), str(c.get("effect", ""))], 14, UI.C_TEXT, true)
		line.custom_minimum_size = Vector2(760.0, 0.0)
		inner.add_child(line)
		var tip: Label = UI.label("Tip: " + str(c.get("tip", "")), 13, UI.C_CYAN, true)
		tip.custom_minimum_size = Vector2(760.0, 0.0)
		inner.add_child(tip)
		col.add_child(card)


func _build_log() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(20, 430), Vector2(640, 220))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("What happened on the way", 18))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600.0, 140.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var lines: VBoxContainer = UI.vbox(4)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	if GameState.log_lines.is_empty():
		lines.add_child(UI.label("Nothing unusual happened.", 14, UI.C_MUTED))
	for item in GameState.log_lines:
		var text: Label = UI.label("- " + str(item), 14, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(580.0, 0.0)
		lines.add_child(text)


func _build_compare() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(676, 430), Vector2(584, 220))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("Compare with a real mission", 18))
	var text: Label = UI.label("Real mission figures will be added from verified NASA data.", 14, UI.C_MUTED, true)
	text.custom_minimum_size = Vector2(540.0, 0.0)
	col.add_child(text)


func _build_buttons() -> void:
	_place(UI.button("Retry with changes", _on_retry, 260.0, true), Vector2(20, 660), Vector2(260, 52))
	_place(UI.button("New design", _on_new, 220.0, false), Vector2(296, 660), Vector2(220, 52))
	_place(UI.button("Title", _on_title, 160.0, false), Vector2(1100, 660), Vector2(160, 52))


func _on_retry() -> void:
	GameState.retry_mission()
	GameState.go("workshop")


func _on_new() -> void:
	GameState.reset_mission()
	GameState.go("briefing")


func _on_title() -> void:
	GameState.go("title")
