extends Control
## Title screen. Also the example of how every screen is written:
## extend Control, build nodes in _ready(), change screen with GameState.go().

const UI = preload("res://scripts/ui/ui.gd")
const SimTests = preload("res://tests/sim_tests.gd")

var _test_label: Label = null


func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v: VBoxContainer = UI.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	v.add_child(UI.picture("res://art/ui/ui_logo.png", Vector2(640, 240), "Space Mission Designer"))
	v.add_child(UI.label("Plan it. Build it. Launch it. Find out why it worked.", 18, UI.C_MUTED))
	var row: HBoxContainer = UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	row.add_child(UI.button("Play", _on_play, 220.0, true))
	row.add_child(UI.button("Skip to the mission", _on_mission))
	var tools: HBoxContainer = UI.hbox(16)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tools)
	tools.add_child(UI.button("Run self-test", _on_self_test, 180.0))
	tools.add_child(UI.button("Reset progress", _on_reset, 180.0))
	_test_label = UI.label("", 13, UI.C_MUTED, true)
	_test_label.custom_minimum_size = Vector2(760, 0)  # a wrapping label needs a width
	_test_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_test_label)


func _on_play() -> void:
	GameState.go("ladder")


func _on_mission() -> void:
	GameState.reset_mission()
	GameState.go("briefing")


func _on_reset() -> void:
	GameState.reset_progress()
	_test_label.text = "Progress cleared."


func _on_self_test() -> void:
	var fails: Array = SimTests.run()
	if fails.is_empty():
		_test_label.text = "Self-test: all checks passed."
	else:
		_test_label.text = "Self-test FAILED:\n" + "\n".join(PackedStringArray(fails))
