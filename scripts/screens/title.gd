extends Control
## Title screen. Also the example of how every screen is written:
## extend Control, build nodes in _ready(), change screen with GameState.go().
##
## Layout: logo and a one-line description at the top, a tiny progress bar under it, the
## main choices in the middle, quick settings on the right, the player's name plate at the
## bottom. The full settings live in the menu button at the side of every screen (menu.gd).

const UI = preload("res://scripts/ui/ui.gd")
const SimTests = preload("res://tests/sim_tests.gd")
const Player = preload("res://scripts/ui/player.gd")
const Logo = preload("res://scripts/ui/logo.gd")
const Confirm = preload("res://scripts/ui/confirm.gd")

var _test_label: Label = null
var _sound_button: Button = null
var _progress_bar: ProgressBar = null
var _progress_label: Label = null


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _ready() -> void:
	_build_header()
	_build_main_choices()
	_build_side_settings()
	_build_profile()
	_test_label = UI.label("", 13, UI.C_MUTED, true)
	_place(_test_label, Vector2(20, 640), Vector2(330, 70))


func _build_header() -> void:
	var top: VBoxContainer = UI.vbox(10)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_place(top, Vector2(140, 26), Vector2(1000, 250))
	if ResourceLoader.exists("res://art/ui/ui_logo.png"):
		top.add_child(UI.picture("res://art/ui/ui_logo.png", Vector2(640, 170), "Space Mission Designer"))
	else:
		top.add_child(Logo.new())
	var desc: Label = UI.label("Design a small satellite, launch it, and keep it working in orbit.\nEvery part you pick trades mass, power, data, money and time against each other.", 17, UI.C_MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(desc)
	# a thin progress line, not a big bar
	var row: HBoxContainer = UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(row)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.custom_minimum_size = Vector2(240.0, 5.0)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.10), 3, 0, 0.0))
	_progress_bar.add_theme_stylebox_override("fill", UI.box(UI.C_ACCENT, UI.C_ACCENT, 3, 0, 0.0))
	row.add_child(_progress_bar)
	_progress_label = UI.label("", 13, UI.C_ACCENT)
	row.add_child(_progress_label)
	_refresh_progress()


func _refresh_progress() -> void:
	var pct: float = GameState.progress_pct()
	_progress_bar.value = pct
	_progress_label.text = "%d%% complete" % int(round(pct))


## One big choice: a button with a short line under it saying what it does.
func _choice(col: VBoxContainer, text: String, note: String, on_press: Callable, primary: bool) -> void:
	var b: Button = UI.button(text, on_press, 420.0, primary)
	b.custom_minimum_size = Vector2(420.0, 54.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	var l: Label = UI.label(note, 13, UI.C_MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)


func _build_main_choices() -> void:
	var col: VBoxContainer = UI.vbox(4)
	_place(col, Vector2(400, 296), Vector2(480, 330))
	_choice(col, "Play", "The full run: 4 training puzzles, then the missions.", _on_play, true)
	col.add_child(_gap(10))
	_choice(col, "Skip to the missions", "Already trained? Go straight to the main game.", _on_mission, false)
	col.add_child(_gap(10))
	var row: HBoxContainer = UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UI.button("How to play", _on_guide, 204.0, false))
	row.add_child(UI.button("Training puzzles", _on_training, 204.0, false))
	col.add_child(_gap(10))
	_choice(col, "NASA problem: can the truck see?", "A real-world bonus challenge.", _on_truck, false)


func _gap(h: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c


## Quick settings on the right. Everything else is in the menu button.
func _build_side_settings() -> void:
	var col: VBoxContainer = UI.vbox(10)
	_place(col, Vector2(1060, 296), Vector2(200, 200))
	col.add_child(UI.label("Quick settings", 13, UI.C_MUTED))
	_sound_button = UI.button("", _on_sound, 200.0, false)
	_sound_button.custom_minimum_size = Vector2(200.0, 44.0)
	_sound_button.text = _sound_text()
	col.add_child(_sound_button)
	var tips: Button = UI.button("Show tips again", _on_tips, 200.0, false)
	tips.custom_minimum_size = Vector2(200.0, 44.0)
	col.add_child(tips)
	var reset: Button = UI.button("Reset progress", _on_reset, 200.0, false)
	reset.custom_minimum_size = Vector2(200.0, 44.0)
	col.add_child(reset)
	var more: Label = UI.label("More options: the menu button\non the left edge.", 12, UI.C_MUTED)
	col.add_child(more)


func _build_profile() -> void:
	var row: HBoxContainer = UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(row, Vector2(390, 640), Vector2(500, 60))
	if GameState.has_profile():
		row.add_child(Player.badge(44.0))
	var b: Button = UI.button("Customise astronaut" if GameState.has_profile() else "Create your astronaut", _on_customise, 240.0, false)
	b.custom_minimum_size = Vector2(240.0, 48.0)
	row.add_child(b)
	var test: Button = UI.button("Self-test", _on_self_test, 110.0, false)
	test.custom_minimum_size = Vector2(110.0, 36.0)
	test.add_theme_font_size_override("font_size", 14)
	_place(test, Vector2(1150, 664), Vector2(110, 36))


func _on_play() -> void:
	GameState.profile_next = "ladder"
	if not GameState.has_profile():
		GameState.go("profile")
		return
	GameState.go("ladder")


func _on_training() -> void:
	_on_play()


func _on_guide() -> void:
	GameState.go("guide")


func _on_customise() -> void:
	GameState.profile_next = "title"
	GameState.go("profile")


func _on_mission() -> void:
	if not GameState.has_profile():
		GameState.profile_next = "missions"
		GameState.go("profile")
		return
	GameState.go("missions")


func _on_truck() -> void:
	GameState.go("truck")


func _sound_text() -> String:
	return "Sound effects: off" if GameState.muted else "Sound effects: on"


func _on_sound() -> void:
	GameState.set_muted(not GameState.muted)
	_sound_button.text = _sound_text()


func _on_tips() -> void:
	GameState.reset_tutorial()
	_test_label.text = "Tips will show again on each screen."


func _on_reset() -> void:
	Confirm.ask(self, "Reset progress?", "This clears every finished puzzle, mission and star. Your astronaut and settings stay.", "Yes, reset", _do_reset)


func _do_reset() -> void:
	GameState.reset_progress()
	_refresh_progress()
	_test_label.text = "Progress cleared."


func _on_self_test() -> void:
	var fails: Array = SimTests.run()
	if fails.is_empty():
		_test_label.text = "Self-test: all checks passed."
	else:
		_test_label.text = "Self-test FAILED:\n" + "\n".join(PackedStringArray(fails))
