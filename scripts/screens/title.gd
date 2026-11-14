extends Control
## Title screen. Also the example of how every screen is written:
## extend Control, build nodes in _ready(), change screen with GameState.go().

const UI = preload("res://scripts/ui/ui.gd")
const SimTests = preload("res://tests/sim_tests.gd")
const Player = preload("res://scripts/ui/player.gd")

var _test_label: Label = null
var _sound_button: Button = null


func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = UI.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	v.add_child(UI.picture("res://art/ui/ui_logo.png", Vector2(640, 240), "Space Mission Designer"))
	v.add_child(UI.label("Plan it. Build it. Launch it. Find out why it worked.", 18, UI.C_MUTED))
	if GameState.has_profile():
		var greet: Control = Player.badge(56.0)
		greet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(greet)
		var welcome: Label = UI.label("Welcome back, %s." % GameState.display_name(), 18, UI.C_CYAN)
		welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(welcome)
	var row: HBoxContainer = UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.button("Play", _on_play, 220.0, true))
	row.add_child(UI.button("Skip to the mission", _on_mission))
	var truck_row: HBoxContainer = UI.hbox(16)
	truck_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(truck_row)
	truck_row.add_child(UI.button("NASA problem: can the truck see?", _on_truck, 420.0, true))
	var tools: HBoxContainer = UI.hbox(16)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tools)
	tools.add_child(UI.button("Run self-test", _on_self_test, 180.0))
	_sound_button = UI.button("", _on_sound, 180.0)
	_sound_button.text = _sound_text()
	tools.add_child(_sound_button)
	tools.add_child(UI.button("Show tips again", _on_tips, 180.0))
	tools.add_child(UI.button("Reset progress", _on_reset, 180.0))
	var custom_row: HBoxContainer = UI.hbox(16)
	custom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(custom_row)
	custom_row.add_child(UI.button("Customise astronaut", _on_customise, 240.0))
	_test_label = UI.label("", 13, UI.C_MUTED, true)
	_test_label.custom_minimum_size = Vector2(760, 0)  # a wrapping label needs a width
	_test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_test_label)


func _on_play() -> void:
	if not GameState.has_profile():
		GameState.profile_next = "ladder"
		GameState.go("profile")
		return
	GameState.go("ladder")


func _on_customise() -> void:
	GameState.profile_next = "title"
	GameState.go("profile")


func _on_mission() -> void:
	GameState.go("missions")


func _on_truck() -> void:
	GameState.go("truck")


func _sound_text() -> String:
	return "Sound: off" if GameState.muted else "Sound: on"


func _on_sound() -> void:
	GameState.set_muted(not GameState.muted)
	_sound_button.text = _sound_text()


func _on_tips() -> void:
	GameState.reset_tutorial()
	_test_label.text = "Tips will show again on each screen."


func _on_reset() -> void:
	GameState.reset_progress()
	_test_label.text = "Progress cleared."


func _on_self_test() -> void:
	var fails: Array = SimTests.run()
	if fails.is_empty():
		_test_label.text = "Self-test: all checks passed."
	else:
		_test_label.text = "Self-test FAILED:\n" + "\n".join(PackedStringArray(fails))
