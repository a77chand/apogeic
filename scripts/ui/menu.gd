extends Control
## The menu: a small tab on the left edge of every screen. Clicking it opens a panel with
## sound and music volume, text size, tips, sources, reset progress, home and quit.
## Two small tabs under it go home and quit at any time.
## While the panel is open the game is paused (clocks, timers and animations wait).
## main.gd adds one of these on top of the screens.

const UI = preload("res://scripts/ui/ui.gd")
const Confirm = preload("res://scripts/ui/confirm.gd")
const Sources = preload("res://scripts/ui/sources.gd")

const TAB_RECT: Rect2 = Rect2(0, 180, 17, 84)   # narrow: screens start at x = 20

var _tab: Button = null
var _layer: Control = null        # the open panel and its dim background, or null
var _note: Label = null
var _size_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab = Button.new()
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.tooltip_text = "Menu"
	_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb: StyleBoxFlat = UI.box(Color(0.03, 0.07, 0.15, 0.92), Color(UI.C_ACCENT, 0.8), 8, 1, 0.0)
	sb.border_width_left = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_detail = 1
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(0.08, 0.17, 0.30, 0.98)
	hover.shadow_color = Color(UI.C_ACCENT, 0.35)
	hover.shadow_size = 8
	_tab.add_theme_stylebox_override("normal", sb)
	_tab.add_theme_stylebox_override("hover", hover)
	_tab.add_theme_stylebox_override("pressed", hover)
	_tab.position = TAB_RECT.position
	_tab.size = TAB_RECT.size
	_tab.pressed.connect(_open)
	_tab.draw.connect(_draw_tab_icon)
	add_child(_tab)
	# two small tabs under it: home, and quit (a power symbol)
	_side_tab(Vector2(0, TAB_RECT.end.y + 8.0), "Exit to home", _on_home, "home")
	_side_tab(Vector2(0, TAB_RECT.end.y + 54.0), "Quit game", _on_exit, "power")


func _side_tab(pos: Vector2, tip: String, on_press: Callable, icon: String) -> void:
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var accent: Color = UI.C_RED if icon == "power" else UI.C_ACCENT
	var sb: StyleBoxFlat = UI.box(Color(0.03, 0.07, 0.15, 0.92), Color(accent, 0.8), 8, 1, 0.0)
	sb.border_width_left = 0
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_left = 0
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = Color(0.08, 0.17, 0.30, 0.98)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.position = pos
	b.size = Vector2(17, 40)
	b.pressed.connect(on_press)
	b.draw.connect(func() -> void:
		var m: Vector2 = Vector2(8, 20)
		if icon == "home":
			b.draw_colored_polygon(PackedVector2Array([m + Vector2(-6, -1), m + Vector2(0, -7), m + Vector2(6, -1)]), accent)
			b.draw_rect(Rect2(m + Vector2(-4, -1), Vector2(8, 7)), accent)
		else:
			b.draw_arc(m + Vector2(0, 1), 5.5, -PI * 0.3, PI * 1.3, 16, accent, 2.0)
			b.draw_line(m + Vector2(0, -6), m + Vector2(0, 0), accent, 2.0))
	add_child(b)


## Three short lines (a "hamburger") and a dot, drawn in code.
func _draw_tab_icon() -> void:
	var c: Color = Color(UI.C_ACCENT, 0.95)
	for i in range(3):
		var y: float = 36.0 + float(i) * 8.0
		_tab.draw_line(Vector2(3, y - 6.0), Vector2(13, y - 6.0), c, 2.0)


func is_open() -> bool:
	return _layer != null and is_instance_valid(_layer)


func _open() -> void:
	if is_open():
		return
	GameState.play_sound("click")
	get_tree().paused = true
	_layer = Control.new()
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_layer)
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 18.0)
	_layer.add_child(panel)
	panel.position = Vector2(-380, 24)
	panel.size = Vector2(380, 672)
	panel.custom_minimum_size = Vector2(380, 672)
	panel.create_tween().tween_property(panel, "position:x", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(8)
	col.add_child(head)
	var title: Label = UI.label("Menu", 26, UI.C_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close: Button = UI.button("Close", _close, 100.0, false)
	close.custom_minimum_size = Vector2(100.0, 40.0)
	head.add_child(close)

	col.add_child(_section("Sound"))
	col.add_child(_volume_row("Buttons and effects", GameState.sfx_volume, not GameState.muted, _on_sfx_volume, _on_sfx_toggle))
	col.add_child(_volume_row("Music", GameState.music_volume, not GameState.music_muted, _on_music_volume, _on_music_toggle))

	col.add_child(_section("Text size"))
	var sizes: HBoxContainer = UI.hbox(8)
	col.add_child(sizes)
	for item in [["small", "Small"], ["medium", "Medium"], ["large", "Large"]]:
		var pair: Array = item
		var b: Button = UI.button(str(pair[1]), _on_size.bind(str(pair[0])), 104.0, false)
		b.custom_minimum_size = Vector2(104.0, 40.0)
		sizes.add_child(b)
		_size_buttons[str(pair[0])] = b
	_style_sizes()

	col.add_child(_section("Game"))
	if GameState.in_mission():
		col.add_child(_menu_button("Quit this mission", _on_quit_mission, false))
	col.add_child(_menu_button("How to play", _on_guide, false))
	col.add_child(_menu_button("Resources and sources", _on_sources, false))
	col.add_child(_menu_button("About the team", _on_team, false))
	col.add_child(_menu_button("Show tips again", _on_tips, false))
	col.add_child(_menu_button("Reset progress", _on_reset, false))
	_note = UI.label("", 13, UI.C_YELLOW, true)
	_note.custom_minimum_size = Vector2(340.0, 0.0)
	col.add_child(_note)
	# leaving: two different buttons, so going home is never mixed up with quitting
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	var leave: HBoxContainer = UI.hbox(10)
	col.add_child(leave)
	leave.add_child(_leave_button("Exit to home", _on_home, UI.C_CYAN))
	leave.add_child(_leave_button("Quit game", _on_exit, UI.C_RED))


func _section(text: String) -> Label:
	var l: Label = UI.label(text.to_upper(), 12, UI.C_MUTED)
	l.add_theme_constant_override("outline_size", 1)
	return l


func _menu_button(text: String, on_press: Callable, primary: bool) -> Button:
	var b: Button = UI.button(text, on_press, 340.0, primary)
	b.custom_minimum_size = Vector2(340.0, 36.0)
	b.add_theme_font_size_override("font_size", UI.fs(16))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _leave_button(text: String, on_press: Callable, accent: Color) -> Button:
	var b: Button = UI.button(text, on_press, 165.0, false)
	b.custom_minimum_size = Vector2(165.0, 42.0)
	b.add_theme_font_size_override("font_size", UI.fs(16))
	b.add_theme_color_override("font_color", accent)
	b.add_theme_stylebox_override("normal", UI.box(Color(accent, 0.12), accent, 8, 2, 8.0))
	b.add_theme_stylebox_override("hover", UI.box(Color(accent, 0.28), accent, 8, 2, 8.0))
	return b


## A row: a name, an on/off button, and a volume slider.
func _volume_row(text: String, volume: float, on: bool, on_slide: Callable, on_toggle: Callable) -> VBoxContainer:
	var box: VBoxContainer = UI.vbox(2)
	var head: HBoxContainer = UI.hbox(8)
	box.add_child(head)
	var name_label: Label = UI.label(text, 15, UI.C_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var pct: Label = UI.label("%d%%" % int(round(volume * 100.0)), 14, UI.C_ACCENT)
	head.add_child(pct)
	var toggle: Button = UI.button("On" if on else "Muted", Callable(), 84.0, false)
	toggle.custom_minimum_size = Vector2(84.0, 32.0)
	toggle.add_theme_font_size_override("font_size", UI.fs(15))
	toggle.pressed.connect(func() -> void:
		var now_on: bool = toggle.text != "On"
		toggle.text = "On" if now_on else "Muted"
		on_toggle.call(now_on))
	head.add_child(toggle)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.set_value_no_signal(volume * 100.0)
	slider.custom_minimum_size = Vector2(340.0, 22.0)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v))
		on_slide.call(v / 100.0))
	box.add_child(slider)
	return box


func _style_sizes() -> void:
	for key in _size_buttons.keys():
		var b: Button = _size_buttons[key]
		var chosen: bool = str(key) == GameState.font_size
		var fill: Color = UI.C_BTN_MAIN if chosen else UI.C_BTN
		b.add_theme_stylebox_override("normal", UI.chunky(fill, Color(UI.C_ACCENT, 0.75), false))


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close()


func _close() -> void:
	if is_open():
		_layer.queue_free()
	_layer = null
	get_tree().paused = false


## Leaving a mission part-way: costs a life, then goes to the screen.
func _abandon(screen: String) -> void:
	GameState.abandon_mission()
	_go(screen)


func _go(screen: String) -> void:
	_close()
	GameState.go(screen)


# ---------------------------------------------------------------- actions

func _on_sfx_volume(v: float) -> void:
	GameState.set_sfx_volume(v)


func _on_sfx_toggle(on: bool) -> void:
	GameState.set_muted(not on)


func _on_music_volume(v: float) -> void:
	GameState.set_music_volume(v)


func _on_music_toggle(on: bool) -> void:
	GameState.set_music_muted(not on)


## Text size changes body text. Screens that keep no state are rebuilt at once; on the
## others (mid-puzzle or mid-mission) it applies from the next screen, so nothing is lost.
func _on_size(value: String) -> void:
	GameState.set_font_size(value)
	_style_sizes()
	var screen: String = str(GameState.router.call("current_id")) if GameState.router != null else ""
	if screen in ["title", "ladder", "missions", "briefing", "profile", "guide", "report"]:
		_note.text = ""
		GameState.go(screen)
		_close()
	else:
		_note.text = "Text size changes from the next screen, so this one keeps your work."


func _host() -> Control:
	return _layer if is_open() else self


func _on_home() -> void:
	if GameState.in_mission():
		Confirm.ask(_host(), "Leave this mission?", "You are in the middle of a mission. Going home now loses this attempt and costs 1 life (you have %d)." % GameState.lives, "Yes, go home (-1 life)", _abandon.bind("title"))
		return
	_go("title")


func _on_quit_mission() -> void:
	Confirm.ask(_layer, "Quit this mission?", "Your parts and progress on this attempt will be lost, and it costs 1 life (you have %d)." % GameState.lives, "Yes, quit (-1 life)", _abandon.bind("missions"))


func _on_guide() -> void:
	if GameState.in_mission():
		Confirm.ask(_layer, "Leave the mission?", "Opening the guide leaves this mission, loses this attempt and costs 1 life (you have %d)." % GameState.lives, "Yes, open guide (-1 life)", _abandon.bind("guide"))
		return
	_go("guide")


func _on_sources() -> void:
	var s: Control = Sources.new()
	_layer.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The team behind the game, by role (Nebula Forge).
const TEAM: Array = [
	["Artistry & animation", ["Adity Agrawal", "Tanvi Padala"]],
	["Software development", ["Anusha Chandra", "Aadhav Dijay", "Bhairavi Swaminathan"]],
	["Team management", ["Amudha Lakshmanan"]],
]


func _on_team() -> void:
	var box: Control = Control.new()
	box.process_mode = Node.PROCESS_MODE_ALWAYS
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 24.0)
	panel.custom_minimum_size = Vector2(560.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	var title: Label = UI.label("About the team", 26, UI.C_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var team: Label = UI.label("Nebula Forge  ·  NASA Space Apps 2026", 15, UI.C_GOLD)
	team.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(team)
	for item in TEAM:
		var role: Array = item
		var head: Label = UI.label(str(role[0]), 17, UI.C_ACCENT)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(head)
		var names: Label = UI.label("  ·  ".join(PackedStringArray(role[1])), 16, UI.C_TEXT, true)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		names.custom_minimum_size = Vector2(500.0, 0.0)
		col.add_child(names)
	var close: Button = UI.button("Close", box.queue_free, 160.0, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close)


func _on_tips() -> void:
	GameState.reset_tutorial()
	_note.text = "Tips will show again on each screen."


func _on_reset() -> void:
	Confirm.ask(_layer, "Reset progress?", "This clears every finished puzzle, mission and star. Your astronaut and settings stay.", "Yes, reset", _do_reset)


func _do_reset() -> void:
	GameState.reset_progress()
	_note.text = "Progress cleared."
	var screen: String = str(GameState.router.call("current_id")) if GameState.router != null else ""
	if screen in ["title", "ladder", "missions"]:
		_go(screen)


func _on_exit() -> void:
	Confirm.ask(_host(), "Quit the game?", "Your finished puzzles, missions and stars are saved. A mission in progress is not.", "Yes, quit", _do_exit)


## On the desktop the game closes. A browser tab cannot be closed by the page, so the web
## build shows a goodbye screen instead.
func _do_exit() -> void:
	_close()
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	var bye: Control = Control.new()
	bye.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bye)
	bye.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dark: ColorRect = ColorRect.new()
	dark.color = Color(0.01, 0.01, 0.03)
	bye.add_child(dark)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = UI.vbox(18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	bye.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var t: Label = UI.label("Thanks for playing", 30, UI.C_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var n: Label = UI.label("Your progress is saved. You can close this tab now.", 16, UI.C_MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(n)
	var back: Button = UI.button("Back to the game", func() -> void:
		bye.queue_free()
		GameState.go("title"), 240.0, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(back)
