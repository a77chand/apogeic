extends Control
## Report: stars, numbers, and the plain-language cause chain.
## Reads only from GameState and recomputes everything with Sim (spec 12.13).

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const WeekChart = preload("res://scripts/ui/week_chart.gd")

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
	_build_chart()
	_build_log()
	_build_buttons()
	var grade: String = str(score.get("grade", "failed"))
	GameState.play_sound("fanfare" if grade == "success" else ("chime" if int(score.get("stars", 0)) > 0 else "fail"))
	if int(score.get("stars", 0)) >= 1:
		_celebrate(int(score.get("stars", 0)))
	else:
		Tutorial.maybe_show(self, "report")


## The end of a mission with stars: your astronaut jumps with a speech bubble. Three stars
## gets the big jump and "Well done!", fewer stars a smaller hop and a gentler word.
## Star dust earned or a life lost is shown too. Click anywhere (or wait) to close it.
func _celebrate(stars: int) -> void:
	var layer: Control = Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.modulate = Color(1, 1, 1, 0)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fig: Control = Player.figure(320.0)
	layer.add_child(fig)
	fig.position = Vector2(440.0, 250.0)
	fig.call("celebrate", 0.08 if stars >= 3 else 0.035)
	var bubble: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = UI.box(Color(0.98, 0.97, 0.92), UI.C_GOLD if stars >= 3 else UI.C_CYAN, 18, 3, 16.0)
	bubble.add_theme_stylebox_override("panel", sb)
	layer.add_child(bubble)
	bubble.position = Vector2(680.0, 200.0)
	var col: VBoxContainer = UI.vbox(6)
	bubble.add_child(col)
	var head: String = ["", "Good start!", "Nice work!", "Well done!"][clampi(stars, 0, 3)]
	var line: String = ["", "One star. The report shows what to fix for the next one.", "Two stars. One more is within reach.", "A perfect mission."][clampi(stars, 0, 3)]
	var dark: Color = Color(0.06, 0.08, 0.14)
	var h: Label = UI.label(head, 30, dark)
	h.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	col.add_child(h)
	var l: Label = UI.label(line, 16, dark, true)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	l.custom_minimum_size = Vector2(320.0, 0.0)
	col.add_child(l)
	col.add_child(UI.star_row(stars, 30.0))
	if GameState.last_reward.has("stardust"):
		var dust: Label = UI.label("+%d star dust" % int(GameState.last_reward["stardust"]), 16, Color(0.45, 0.30, 0.85))
		dust.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		col.add_child(dust)
	var more: Label = UI.label("Click to continue", 12, Color(0.25, 0.45, 0.6))
	more.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	col.add_child(more)
	# the bubble's tail, pointing at the astronaut
	var tail: Control = Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tail)
	tail.draw.connect(func() -> void:
		tail.draw_colored_polygon(PackedVector2Array([Vector2(684, 300), Vector2(684, 340), Vector2(640, 350)]), Color(0.98, 0.97, 0.92)))
	if stars >= 3:
		for i in range(14):
			var spark: Control = _star(true)
			spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spark.scale = Vector2(0.35, 0.35)
			spark.position = Vector2(600.0, 400.0)
			layer.add_child(spark)
			var a: float = TAU * float(i) / 14.0
			var tw: Tween = spark.create_tween()
			tw.tween_interval(0.9)
			tw.tween_property(spark, "position", Vector2(600.0, 400.0) + Vector2(cos(a) * 360.0, sin(a) * 240.0), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(spark, "modulate:a", 0.0, 1.2).set_delay(0.6)
	var show: Tween = layer.create_tween()
	show.tween_interval(0.9)
	show.tween_property(layer, "modulate:a", 1.0, 0.3)
	layer.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free())


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
	col.add_child(UI.button("Back to home", _on_title, 240.0, true))


func _build_top_bar(grade: String) -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title_text: String = "Mission failed"
	var color: Color = UI.C_RED
	if grade == "success":
		title_text = "Mission success"
		color = UI.C_GREEN
	elif grade == "partial":
		title_text = "Partial success"
		color = UI.C_YELLOW
	var art: Control = null
	if grade != "partial":
		art = UI.result_art(grade == "success", 560.0)
	if art != null:
		var mid: CenterContainer = CenterContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(mid)
		mid.add_child(art)
	else:
		var title: Label = UI.label(title_text, 30, color)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(title)
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(14.0, 14.0)
	var tag: Control = UI.based_on_tag(GameState.level, 330.0)
	add_child(tag)
	tag.position = Vector2(930.0, 18.0)


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
	var row_index: int = 0
	for item in rows:
		var row_data: Array = item
		var row: HBoxContainer = UI.hbox(10)
		var star: Control = _star(bool(row_data[0]))
		star.pivot_offset = Vector2(27.0, 27.0)
		star.scale = Vector2.ZERO
		row.add_child(star)
		var pop: Tween = star.create_tween()
		pop.tween_interval(0.25 + 0.3 * float(row_index))
		pop.tween_property(star, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		row_index += 1
		var label: Label = UI.label(str(row_data[1]), 16)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		col.add_child(row)
	var cfg: Dictionary = GameState.level.get("ops", {})
	var ops: Dictionary = GameState.ops
	var delivered_label: Label = UI.label("", 14)
	col.add_child(delivered_label)
	var delivered: float = float(ops.get("delivered_mb", 0.0))
	var goal: int = int(float(cfg.get("goal_mb", 0.0)))
	var count: Tween = delivered_label.create_tween()
	count.tween_method(func(v: float): delivered_label.text = "Delivered: %d of %d MB" % [int(round(v)), goal], 0.0, delivered, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	col.add_child(UI.label("Lost: %d MB   Money left: %s" % [int(round(float(ops.get("lost_mb", 0.0)))), UI.money(float(ops.get("money_k", 0.0)))], 14))
	col.add_child(UI.label("Weeks flown: %d of %d" % [int(ops.get("week", 0)), int(cfg.get("weeks", 12))], 14))
	if GameState.last_reward.has("life_lost"):
		col.add_child(UI.label("No stars: -1 life (%d of %d left)" % [GameState.lives, GameState.MAX_LIVES], 14, UI.C_RED))


func _build_causes(causes: Array) -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(436, 88), Vector2(824, 330))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Why it happened", 20))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(796.0, 266.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list: VBoxContainer = UI.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var start: int = 0
	if str(GameState.ops.get("end_reason", "")) == "launch_failed":
		list.add_child(_launch_card())
		start = 1   # the first cause is the launch failure, already shown above
	var shown: int = mini(start + 3, causes.size())
	for i in range(start, shown):
		var c: Dictionary = causes[i]
		list.add_child(_cause_card(str(c.get("cause", "")), str(c.get("effect", "")), str(c.get("tip", ""))))


## One problem as three short rows: what went wrong, what it did, how to fix it.
func _cause_card(cause: String, effect: String, tip: String) -> Control:
	var card: PanelContainer = UI.panel(UI.C_DISABLED_BORDER, 8.0)
	var inner: VBoxContainer = UI.vbox(3)
	card.add_child(inner)
	inner.add_child(_row("Problem", cause, UI.C_RED))
	inner.add_child(_row("Result", effect, UI.C_ORANGE))
	inner.add_child(_row("Fix", tip, UI.C_GREEN))
	return card


func _row(tag: String, text: String, color: Color) -> HBoxContainer:
	var row: HBoxContainer = UI.hbox(10)
	var t: Label = UI.label(tag.to_upper(), 12, color)
	t.custom_minimum_size = Vector2(70.0, 0.0)
	t.add_theme_constant_override("outline_size", 1)
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(t)
	var body: Label = UI.label(text, 14, UI.C_TEXT, true)
	body.custom_minimum_size = Vector2(680.0, 0.0)
	row.add_child(body)
	return row


## The launch failure: where it broke, and every reason as its own bullet.
func _launch_card() -> Control:
	var outcome: Dictionary = GameState.launch_outcome
	var card: PanelContainer = UI.panel(UI.C_RED, 10.0)
	var inner: VBoxContainer = UI.vbox(4)
	card.add_child(inner)
	var stage: String = str(outcome.get("stage_name", ""))
	var head: String = "The rocket failed at %s" % stage if stage != "" else "The rocket never reached orbit"
	inner.add_child(UI.label(head, 16, UI.C_RED, true))
	var lines: Array = []
	var ready: float = float(outcome.get("readiness_pct", 100.0))
	var needed: float = float(outcome.get("needed_pct", 0.0))
	if ready < needed - 0.01:
		lines.append("Only %d%% of the checks passed. The rocket needs %d%%." % [int(round(ready)), int(round(needed))])
	for item in outcome.get("risks", []):
		var r: Dictionary = item
		lines.append(str(r.get("text", "")))
	if lines.is_empty():
		lines.append(str(outcome.get("fail_text", "")))
	inner.add_child(UI.bullets(lines, 14, UI.C_TEXT, 760.0, UI.C_RED))
	inner.add_child(_row("Fix", "Repair known problems in the test lab, and keep the spacecraft well under the mass limit.", UI.C_GREEN))
	return card


func _build_chart() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(20, 430), Vector2(640, 220))
	var col: VBoxContainer = UI.vbox(4)
	panel.add_child(col)
	col.add_child(UI.label("How the mission went", 18))
	var chart: Control = WeekChart.new()
	col.add_child(chart)
	var cfg: Dictionary = GameState.level.get("ops", {})
	var flags: Array = []
	for week in range(1, int(cfg.get("weeks", 12)) + 1):
		for item in GameState.events_due("ops", week):
			var ev: Dictionary = item
			flags.append({"week": week, "label": str(ev.get("title", ""))})
	var reason: String = str(GameState.ops.get("end_reason", ""))
	var early: bool = reason != "" and reason != "complete"
	var why_empty: String = "There is nothing to chart."
	if reason == "launch_failed":
		why_empty = "The rocket never reached orbit, so there is nothing to chart."
	elif reason == "no_battery":
		why_empty = "The satellite lost power in its first orbit, so there is nothing to chart."
	chart.call("set_data", GameState.ops.get("history", []), float(cfg.get("goal_mb", 1.0)), int(cfg.get("weeks", 12)), flags, early and not (GameState.ops.get("history", []) as Array).is_empty(), why_empty)


func _build_log() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(676, 430), Vector2(584, 220))
	var col: VBoxContainer = UI.vbox(4)
	panel.add_child(col)
	col.add_child(UI.label("What happened on the way", 18))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550.0, 166.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var lines: VBoxContainer = UI.vbox(3)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	if GameState.log_lines.is_empty():
		lines.add_child(UI.label("Nothing unusual happened.", 13, UI.C_MUTED))
	for item in GameState.log_lines:
		var text: Label = UI.label("- " + str(item), 13, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(540.0, 0.0)
		lines.add_child(text)


func _build_buttons() -> void:
	var retry: Button = UI.button("Fix my satellite", _on_retry, 260.0, true)
	retry.tooltip_text = "Back to the workshop with the same parts, so you only change what went wrong."
	_place(retry, Vector2(20, 660), Vector2(260, 52))
	var fresh: Button = UI.button("Start with empty satellite", _on_new, 300.0, false)
	fresh.tooltip_text = "Clears every part. Your old parts can be brought back from the workshop."
	_place(fresh, Vector2(296, 660), Vector2(300, 52))
	_place(UI.button("All missions", _on_missions, 200.0, false), Vector2(612, 660), Vector2(200, 52))
	var next: Button = UI.button("Go to next mission", _on_next, 260.0, GameState.is_mission_done(GameState.mission_id))
	_place(next, Vector2(828, 660), Vector2(260, 52))
	_place(UI.button("Home", _on_title, 156.0, false), Vector2(1104, 660), Vector2(156, 52))


## The next mission in order (the same one again if this one still has no stars).
func _on_next() -> void:
	if not GameState.can_start_mission():
		GameState.go("missions")
		return
	GameState.set_mission(GameState.next_mission_id())
	GameState.go("briefing")


func _on_retry() -> void:
	if not GameState.can_start_mission():
		GameState.go("missions")
		return
	GameState.retry_mission()
	GameState.go("workshop")


func _on_missions() -> void:
	GameState.go("missions")


func _on_new() -> void:
	if not GameState.can_start_mission():
		GameState.go("missions")
		return
	GameState.remember_design()   # so the workshop can offer "Bring back my last parts"
	GameState.reset_mission()
	GameState.go("briefing")


func _on_title() -> void:
	GameState.go("title")
