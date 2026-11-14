extends Control
## Title screen. Also the example of how every screen is written:
## extend Control, build nodes in _ready(), change screen with GameState.go().
##
## Layout (pixel arcade style): the big AP0GEIC 11 title at the top, a turning pixel planet
## at the bottom left, and the menu on the right. The full settings live in the menu button
## at the side of every screen (menu.gd).

const UI = preload("res://scripts/ui/ui.gd")
const SimTests = preload("res://tests/sim_tests.gd")
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
	_build_footer()
	_test_label = UI.label("", 13, UI.C_MUTED, true)
	_place(_test_label, Vector2(24, 560), Vector2(330, 70))


## The pixel title and planet fill the screen; the menu sits on the right, like an arcade
## cabinet's start screen.
func _build_header() -> void:
	if ResourceLoader.exists("res://art/ui/ui_logo.png"):
		_place(UI.picture("res://art/ui/ui_logo.png", Vector2(900, 200), "AP0GEIC 11"), Vector2(190, 40), Vector2(900, 200))
		return
	var logo: Control = Logo.new()
	logo.planet_centre = Vector2(400, 730)
	logo.planet_radius = 250.0
	_place(logo, Vector2.ZERO, Vector2(1280, 720))


func _refresh_progress() -> void:
	var pct: float = GameState.progress_pct()
	_progress_bar.value = pct
	_progress_label.text = "%d%% COMPLETE" % int(round(pct))


## Play and Skip are the two big choices, with the training options between them. The
## astronaut button is small and gold, above them; everything else is small, below.
func _build_main_choices() -> void:
	var cream: Color = Logo.C_CREAM
	var x: float = 800.0
	var w: float = 420.0
	var custom: Button = UI.pixel_button("Customise astronaut" if GameState.has_profile() else "Create astronaut", _on_customise, 240.0, 32.0, 12, UI.C_GOLD)
	_place(custom, Vector2(x + (w - 240.0) * 0.5, 262), Vector2(240, 32))
	_place(UI.pixel_button("Play  >", _on_play, w, 64.0, 30, Color(0.45, 0.78, 1.0)), Vector2(x, 306), Vector2(w, 64))
	_place(UI.pixel_button("How to play", _on_guide, 204.0, 38.0, 13, UI.C_ACCENT), Vector2(x, 382), Vector2(204, 38))
	_place(UI.pixel_button("Training", _on_training, 204.0, 38.0, 13, UI.C_ACCENT), Vector2(x + 216, 382), Vector2(204, 38))
	_place(UI.pixel_button("Skip to missions  >", _on_mission, w, 64.0, 24, Color(0.78, 0.55, 1.0)), Vector2(x, 432), Vector2(w, 64))
	_place(UI.pixel_button("NASA problem: can the truck see?", _on_truck, w, 32.0, 11, Color(UI.C_ACCENT, 0.75)), Vector2(x, 520), Vector2(w, 32))
	_sound_button = UI.pixel_button(_sound_text(), _on_sound, 136.0, 28.0, 10, Color(UI.C_MUTED, 0.8))
	_place(_sound_button, Vector2(x, 562), Vector2(136, 28))
	_place(UI.pixel_button("Tips again", _on_tips, 136.0, 28.0, 10, Color(UI.C_MUTED, 0.8)), Vector2(x + 142, 562), Vector2(136, 28))
	_place(UI.pixel_button("Reset", _on_reset, 136.0, 28.0, 10, Color(UI.C_MUTED, 0.8)), Vector2(x + 284, 562), Vector2(136, 28))
	var row: HBoxContainer = UI.hbox(10)
	_place(row, Vector2(x, 604), Vector2(w, 20))
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 100.0
	_progress_bar.custom_minimum_size = Vector2(260.0, 6.0)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.10), 0, 0, 0.0))
	_progress_bar.add_theme_stylebox_override("fill", UI.box(cream, cream, 0, 0, 0.0))
	row.add_child(_progress_bar)
	_progress_label = UI.label("", 10, cream)
	_progress_label.add_theme_font_override("font", UI.pixel_font(false))
	row.add_child(_progress_label)
	_refresh_progress()


func _build_footer() -> void:
	var credit: Label = UI.label("v 1 . 0   ·   N A S A   S P A C E   A P P S   2 0 2 6", 10, Color(UI.C_MUTED, 0.7))
	credit.add_theme_font_override("font", UI.pixel_font(false))
	_place(credit, Vector2(24, 690), Vector2(500, 16))
	var test: Button = UI.pixel_button("Self-test", _on_self_test, 100.0, 24.0, 9, Color(UI.C_MUTED, 0.6))
	_place(test, Vector2(1156, 684), Vector2(100, 24))


## Play always goes through the astronaut screen first (name and look), then training.
func _on_play() -> void:
	GameState.profile_next = "ladder"
	GameState.go("profile")


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
	return "SOUND: OFF" if GameState.muted else "SOUND: ON"


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
