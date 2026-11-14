extends Control
## The menu: a small tab on the left edge of every screen. Clicking it opens a panel with
## sound and music volume, text size, tips, sources, reset progress, home and quit.
## While the panel is open the game is paused (clocks, timers and animations wait).
## main.gd adds one of these on top of the screens.

const UI = preload("res://scripts/ui/ui.gd")
const Confirm = preload("res://scripts/ui/confirm.gd")
const Sources = preload("res://scripts/ui/sources.gd")

const TAB_RECT: Rect2 = Rect2(0, 300, 26, 96)

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


## Three short lines (a "hamburger") and a dot, drawn in code.
func _draw_tab_icon() -> void:
	var c: Color = Color(UI.C_ACCENT, 0.95)
	for i in range(3):
		var y: float = 36.0 + float(i) * 8.0
		_tab.draw_line(Vector2(6, y), Vector2(19, y), c, 2.0)


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
	col.add_child(_menu_button("Home", _on_home, true))
	if GameState.in_mission():
		col.add_child(_menu_button("Quit this mission", _on_quit_mission, false))
	col.add_child(_menu_button("How to play", _on_guide, false))
	col.add_child(_menu_button("Resources and sources", _on_sources, false))
	col.add_child(_menu_button("Show tips again", _on_tips, false))
	col.add_child(_menu_button("Reset progress", _on_reset, false))
	if not OS.has_feature("web"):
		col.add_child(_menu_button("Exit to desktop", _on_exit, false))
	_note = UI.label("", 13, UI.C_YELLOW, true)
	_note.custom_minimum_size = Vector2(340.0, 0.0)
	col.add_child(_note)


func _section(text: String) -> Label:
	var l: Label = UI.label(text.to_upper(), 12, UI.C_MUTED)
	l.add_theme_constant_override("outline_size", 1)
	return l


func _menu_button(text: String, on_press: Callable, primary: bool) -> Button:
	var b: Button = UI.button(text, on_press, 340.0, primary)
	b.custom_minimum_size = Vector2(340.0, 36.0)
	b.add_theme_font_size_override("font_size", 16)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	toggle.add_theme_font_size_override("font_size", 15)
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


func _on_home() -> void:
	if GameState.in_mission():
		Confirm.ask(_layer, "Quit the game?", "You are in the middle of a mission. If you go home now, you will lose your progress on this attempt.", "Yes, go home", _go.bind("title"))
		return
	_go("title")


func _on_quit_mission() -> void:
	Confirm.ask(_layer, "Quit this mission?", "Your parts and progress on this attempt will be lost. You can pick the mission again.", "Yes, quit", _go.bind("missions"))


func _on_guide() -> void:
	if GameState.in_mission():
		Confirm.ask(_layer, "Leave the mission?", "Opening the guide leaves this mission and loses this attempt.", "Yes, open guide", _go.bind("guide"))
		return
	_go("guide")


func _on_sources() -> void:
	var s: Control = Sources.new()
	_layer.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	Confirm.ask(_layer, "Exit the game?", "Your finished puzzles and missions are saved. A mission in progress is not.", "Yes, exit", _do_exit)


func _do_exit() -> void:
	get_tree().quit()
