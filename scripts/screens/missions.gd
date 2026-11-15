extends Control
## Choose a mission. 20 missions, each based on a real spaceflight, as tall cards that slide
## left and right (arrows, arrow keys or the mouse wheel). "All missions" lists every one
## by name. "Go to next mission" starts the next one in order.
##
## Unlocking (GameState.is_mission_open): a mission opens when the one before it has at
## least one star; every 7 missions is a stage, and the next stage needs 17 of its 21 stars.
## Finished missions can be replayed in any order. Starting a mission needs a life; a
## failed mission (0 stars) costs one, and they come back one every 30 minutes. Star dust
## from 3-star missions buys more lives.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const RocketArt = preload("res://scripts/ui/rocket_art.gd")

const CARD_SIZE: Vector2 = Vector2(400, 470)
const TEXT_W: float = 270.0   # the words; the rocket drawing takes the rest of the width
const CARD_Y: float = 108.0
const GAP: float = 440.0
const C_LOCKED_TEXT: Color = Color(0.56, 0.60, 0.70)

var _cards: Array = []          # one card per mission, then the "more coming" card
var _index: int = 0
var _tip: Label = null
var _lives_label: Label = null
var _dust_label: Label = null
var _buy_btn: Button = null
var _list_layer: Control = null


func _ready() -> void:
	GameState.refresh_lives()
	_build_top_bar()
	_build_stats()
	_build_cards()
	_build_bottom()
	var ids: Array = GameState.mission_ids()
	_index = maxi(0, ids.find(GameState.next_mission_id()))
	_layout(false)
	Tutorial.maybe_show(self, "missions")
	# wrapped text reports a tall size until it knows its width, so lay out again next frame
	await get_tree().process_frame
	if is_inside_tree():
		_layout(false)


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


## The header: the player's badge, the title, and on the right the stars, lives (pixel
## hearts, with the time to the next one) and star dust, in the pixel font.
func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Missions", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, Vector2(540, 0), Vector2(200, 72))
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(40.0, 14.0)


func _pixel_label(text: String, color: Color) -> Label:
	var l: Label = UI.label(text, 14, color)
	l.add_theme_font_override("font", UI.pixel_font(false))
	l.add_theme_font_size_override("font_size", 15)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Three groups on the right of the header, each an icon, a number and a small word saying
## what it is: STARS, LIVES (with the time to the next one) and STAR DUST.
func _build_stats() -> void:
	var row: HBoxContainer = UI.hbox(26)
	row.alignment = BoxContainer.ALIGNMENT_END
	_place(row, Vector2(744, 8), Vector2(526, 56))
	row.add_child(_stat(UI.star_icon(true, 22.0), _pixel_label("%d/%d" % [GameState.total_stars(), GameState.mission_ids().size() * 3], UI.C_GOLD), "STARS"))
	var hearts: HBoxContainer = UI.hbox(2)
	for i in range(GameState.MAX_LIVES):
		hearts.add_child(UI.heart_icon(i < GameState.lives, 18.0))
	_lives_label = _pixel_label("", UI.C_TEXT)
	row.add_child(_stat(hearts, null, "LIVES", _lives_label))
	_dust_label = _pixel_label("", Color(0.82, 0.74, 1.0))
	row.add_child(_stat(UI.sparkle_icon(28.0), _dust_label, "STAR DUST"))
	_buy_btn = UI.pixel_button("+1 life", _on_buy, 84.0, 30.0, 11, UI.C_RED)
	_buy_btn.tooltip_text = "Buy a life for %d star dust" % GameState.LIFE_COST_STARDUST
	_buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_buy_btn)
	_refresh_stats()


## One header group: the icon and value on top, a small caption under them.
func _stat(icon: Control, value: Label, caption: String, extra: Label = null) -> VBoxContainer:
	var col: VBoxContainer = UI.vbox(1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var top: HBoxContainer = UI.hbox(6)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	top.add_child(icon)
	if value != null:
		top.add_child(value)
	var cap: HBoxContainer = UI.hbox(6)
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cap)
	var c: Label = _pixel_label(caption, UI.C_MUTED)
	c.add_theme_font_size_override("font_size", 9)
	cap.add_child(c)
	if extra != null:
		extra.add_theme_font_size_override("font_size", 9)
		cap.add_child(extra)
	return col


func _refresh_stats() -> void:
	var wait: int = GameState.seconds_to_next_life()
	if GameState.lives >= GameState.MAX_LIVES:
		_lives_label.text = "· FULL"
	else:
		_lives_label.text = "· +1 IN %d:%02d" % [wait / 60, wait % 60]
	_lives_label.tooltip_text = "A life comes back every 30 minutes"
	_dust_label.text = "%d" % GameState.stardust
	_buy_btn.disabled = GameState.lives >= GameState.MAX_LIVES or GameState.stardust < GameState.LIFE_COST_STARDUST


func _process(_delta: float) -> void:
	if _lives_label != null and GameState.lives < GameState.MAX_LIVES:
		var before: int = GameState.lives
		_refresh_stats()
		if GameState.lives != before:
			GameState.go("missions")


func _build_cards() -> void:
	var ids: Array = GameState.mission_ids()
	for i in range(ids.size()):
		var card: Control = _card(i, str(ids[i]))
		add_child(card)
		_cards.append(card)
	var more: Control = _more_card()
	add_child(more)
	_cards.append(more)
	# arrows either side
	var left: Button = UI.button("<", _step.bind(-1), 56.0, false)
	_place(left, Vector2(170, CARD_Y + CARD_SIZE.y * 0.5 - 30.0), Vector2(56, 60))
	var right: Button = UI.button(">", _step.bind(1), 56.0, false)
	_place(right, Vector2(1054, CARD_Y + CARD_SIZE.y * 0.5 - 30.0), Vector2(56, 60))


## A mission card: a neon frame; the words on the left and, on the right, a drawing of the
## real rocket the mission flew on, as tall as the card.
func _card(index: int, id: String) -> Control:
	var info: Dictionary = GameState.mission_info(id)
	var done: bool = GameState.is_mission_done(id)
	var open: bool = GameState.is_mission_open(id)
	var border: Color = UI.C_GOLD if done else (UI.C_CYAN if open else UI.C_DISABLED_BORDER)
	var panel: PanelContainer = UI.neon_panel(border, 16.0)
	panel.custom_minimum_size = CARD_SIZE
	panel.size = CARD_SIZE
	panel.pivot_offset = CARD_SIZE * 0.5
	var outer: HBoxContainer = UI.hbox(8)
	panel.add_child(outer)
	var col: VBoxContainer = UI.vbox(7)
	col.custom_minimum_size = Vector2(TEXT_W, 0.0)
	outer.add_child(col)
	var b: Dictionary = info.get("based_on", {})
	var art: Control = RocketArt.new()
	art.rocket = str(b.get("rocket", ""))
	art.custom_minimum_size = Vector2(CARD_SIZE.x - TEXT_W - 48.0, 0.0)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.tooltip_text = "The real rocket: %s" % art.rocket
	if not open:
		art.modulate = Color(1, 1, 1, 0.5)
	outer.add_child(art)
	var stage_text: String = "Stage %d  ·  %s" % [GameState.stage_of(index) + 1, str(info.get("level_label", "Mission %d" % (index + 1)))]
	col.add_child(UI.label(stage_text, 12, UI.C_MUTED))
	var problem: String = str(info.get("main_problem", ""))
	if problem != "":
		var tag: PanelContainer = PanelContainer.new()
		tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tag.add_theme_stylebox_override("panel", UI.box(Color(UI.C_ORANGE, 0.18), UI.C_ORANGE, 6, 1, 4.0))
		tag.add_child(UI.label(problem, 12, UI.C_ORANGE))
		col.add_child(tag)
	col.add_child(UI.label(str(info.get("name", id)), 26, UI.C_TEXT if open else C_LOCKED_TEXT, true))
	col.add_child(UI.star_row(GameState.stars_for(id), 24.0))
	col.add_child(UI.based_on_tag(info, TEXT_W))
	var story: Label = UI.label(str(b.get("story", info.get("goal_text", ""))), 13, UI.C_TEXT if open else C_LOCKED_TEXT, true)
	story.custom_minimum_size = Vector2(TEXT_W, 0.0)
	col.add_child(story)
	if b.has("lesson"):
		var lesson: Label = UI.label("Lesson: " + str(b.get("lesson", "")), 13, UI.C_ACCENT if open else C_LOCKED_TEXT, true)
		lesson.custom_minimum_size = Vector2(TEXT_W, 0.0)
		col.add_child(lesson)
	var limits: Dictionary = info.get("limits", {})
	col.add_child(UI.label("%.1f kg  |  %s  |  day %d" % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(limits.get("deadline_day", 0))], 13, UI.C_YELLOW))
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	if open:
		col.add_child(UI.button("Play again" if done else "Start mission", _on_start.bind(id), TEXT_W, not done))
	else:
		# locked: smaller, greyer words, and the whole card a shade darker
		var lock: Label = UI.label("LOCKED", 12, C_LOCKED_TEXT)
		lock.add_theme_font_override("font", UI.pixel_font(false))
		col.add_child(lock)
		var why: Label = UI.label(GameState.lock_reason(id), 12, C_LOCKED_TEXT, true)
		why.custom_minimum_size = Vector2(TEXT_W, 0.0)
		col.add_child(why)
	panel.set_meta("locked", not open)
	panel.set_meta("shade", 0.6 if not open else 1.0)
	return panel


func _more_card() -> Control:
	var panel: PanelContainer = UI.neon_panel(UI.C_DISABLED_BORDER, 16.0)
	panel.custom_minimum_size = CARD_SIZE
	panel.size = CARD_SIZE
	panel.pivot_offset = CARD_SIZE * 0.5
	var col: VBoxContainer = UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var head: Label = UI.label("More missions incoming", 26, UI.C_ACCENT, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(head)
	var t: Label = UI.label("New missions based on real spaceflights are on the way.", 15, UI.C_MUTED, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(t)
	panel.set_meta("locked", true)
	panel.set_meta("shade", 0.8)
	return panel


## Puts the cards in place: the chosen one in the middle, its neighbours smaller and dimmer
## at the sides. animate = slide there.
func _layout(animate: bool) -> void:
	var cx: float = 640.0
	for i in range(_cards.size()):
		var card: Control = _cards[i]
		var off: int = i - _index
		var target: Vector2 = Vector2(cx - CARD_SIZE.x * 0.5 + float(off) * GAP, CARD_Y)
		var sc: float = 1.0 if off == 0 else 0.84
		var alpha: float = 1.0 if off == 0 else (0.45 if absi(off) == 1 else 0.0)
		var shade: float = float(card.get_meta("shade", 1.0))
		var tint: Color = Color(shade, shade, shade * 1.05, alpha)
		card.size = CARD_SIZE   # containers can stretch it; keep every card the same size
		card.visible = absi(off) <= 2
		card.mouse_filter = Control.MOUSE_FILTER_STOP if off == 0 else Control.MOUSE_FILTER_IGNORE
		for child in card.find_children("*", "Button", true, false):
			(child as Button).disabled = off != 0 or bool(card.get_meta("locked", false))
		if animate:
			var tw: Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "position", target, 0.32)
			tw.tween_property(card, "scale", Vector2(sc, sc), 0.32)
			tw.tween_property(card, "modulate", tint, 0.32)
		else:
			card.position = target
			card.scale = Vector2(sc, sc)
			card.modulate = tint
	# the middle card draws over its neighbours: move it to the end of the cards (not above
	# overlays such as tips or the list, which are added after the cards)
	var top: int = 0
	for c in _cards:
		top = maxi(top, (c as Control).get_index())
	move_child(_cards[_index], top)
	if _tip != null:
		_tip.text = "Mission %d of %d. Use the arrows, the arrow keys or the mouse wheel to slide." % [mini(_index + 1, GameState.mission_ids().size()), GameState.mission_ids().size()]


func _step(delta: int) -> void:
	var to: int = clampi(_index + delta, 0, _cards.size() - 1)
	if to == _index:
		return
	_index = to
	GameState.play_sound("select")
	_layout(true)


func _unhandled_input(event: InputEvent) -> void:
	if _list_layer != null:
		return
	if event.is_action_pressed("ui_left"):
		_step(-1)
	elif event.is_action_pressed("ui_right"):
		_step(1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_step(1)


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	_tip = UI.label("", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 606), Vector2(160, 50))
	_place(UI.button("All missions", _on_list, 220.0, false), Vector2(530, 606), Vector2(220, 50))
	_place(UI.button("Go to next mission", _on_next, 260.0, true), Vector2(1000, 606), Vector2(260, 50))


func _on_start(id: String) -> void:
	if not GameState.can_start_mission():
		var wait: int = GameState.seconds_to_next_life()
		_tip.text = "No lives left. The next one comes back in %d:%02d, or buy one with %d star dust." % [wait / 60, wait % 60, GameState.LIFE_COST_STARDUST]
		GameState.play_sound("fail")
		return
	GameState.set_mission(id)
	GameState.go("briefing")


func _on_next() -> void:
	var id: String = GameState.next_mission_id()
	var i: int = GameState.mission_ids().find(id)
	if i != _index:
		_index = i
		_layout(true)
	_on_start(id)


func _on_buy() -> void:
	if GameState.buy_life():
		GameState.play_sound("chime")
		GameState.go("missions")


## Every mission by name, in a list. Click an open one to slide to it.
func _on_list() -> void:
	_list_layer = Control.new()
	_list_layer.z_index = 10   # above the middle card
	_list_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_list_layer)
	_list_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	_list_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 18.0)
	_list_layer.add_child(panel)
	panel.position = Vector2(170, 70)
	panel.size = Vector2(940, 580)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(10)
	col.add_child(head)
	var title: Label = UI.label("All missions", 26, UI.C_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.button("Close", _close_list, 120.0, false))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	var ids: Array = GameState.mission_ids()
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var open: bool = GameState.is_mission_open(id)
		var info: Dictionary = GameState.mission_info(id)
		var row: Button = Button.new()
		row.custom_minimum_size = Vector2(440.0, 42.0)
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var s: int = GameState.stars_for(id)
		row.text = "%02d   %s%s" % [i + 1, str(info.get("name", id)), "" if open else "   LOCKED"]
		if open:
			var stars_row: HBoxContainer = UI.star_row(s, 18.0)
			row.add_child(stars_row)
			stars_row.position = Vector2(350.0, 12.0)
		row.add_theme_font_size_override("font_size", 15 if open else 13)
		row.add_theme_color_override("font_color", UI.C_TEXT if open else C_LOCKED_TEXT)
		row.add_theme_color_override("font_disabled_color", C_LOCKED_TEXT)
		var fill: Color = Color(0.04, 0.09, 0.17) if open else Color(0.02, 0.03, 0.06)
		row.add_theme_stylebox_override("normal", UI.box(fill, Color(UI.C_GOLD if s > 0 else UI.C_BORDER, 0.6) if open else Color(UI.C_DISABLED_BORDER, 0.4), 6, 1, 10.0))
		row.add_theme_stylebox_override("hover", UI.box(fill.lightened(0.1), UI.C_CYAN, 6, 1, 10.0))
		row.add_theme_stylebox_override("disabled", UI.box(fill, Color(UI.C_DISABLED_BORDER, 0.4), 6, 1, 10.0))
		row.disabled = not open
		row.pressed.connect(_pick_from_list.bind(i))
		grid.add_child(row)
	var more: Label = UI.label("21+   More missions incoming", 13, C_LOCKED_TEXT)
	col.add_child(more)


func _pick_from_list(i: int) -> void:
	_close_list()
	_index = i
	GameState.play_sound("select")
	_layout(true)


func _close_list() -> void:
	if _list_layer != null:
		_list_layer.queue_free()
		_list_layer = null


func _on_back() -> void:
	GameState.go("title")
