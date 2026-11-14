
extends Control

const UI = preload("res://scripts/ui/ui.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")
const Sim = preload("res://scripts/core/sim.gd")
const GanttChart = preload("res://scripts/ui/gantt_chart.gd")

var _pz: Dictionary = {}
var _build_id: String = "normal"
var _test_id: String = "full"
var _licence_start: int = 60

var _chart: Control
var _result_label: Label
var _build_buttons: Array = []
var _test_buttons: Array = []
var _licence_slider: HSlider
var _licence_label: Label
var _top_bar: Control
var _tip_bar: Control


func _ready() -> void:
	_load_puzzle_data()
	_build_screen()
	_update_screen()


func _load_puzzle_data() -> void:
	var file: FileAccess = FileAccess.open(
		"res://data/puzzles.json",
		FileAccess.READ
	)

	if file == null:
		push_error("Could not open puzzles.json")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not (parsed is Dictionary):
		push_error("puzzles.json is not a valid Dictionary")
		return

	var all_puzzles: Dictionary = parsed
	_pz = all_puzzles.get("time", {})

	_licence_start = int(_pz.get("licence_start_default", 60))


func _build_screen() -> void:
	var main: VBoxContainer = UI.vbox(14)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("margin_left", 24)
	main.add_theme_constant_override("margin_right", 24)
	main.add_theme_constant_override("margin_top", 18)
	main.add_theme_constant_override("margin_bottom", 18)
	add_child(main)

	_top_bar = Chrome.top_bar("BUDGET AND TIME", ["PUZZLE 4"])
	main.add_child(_top_bar)

	var heading: Label = UI.label(
		str(_pz.get("title", "Puzzle 4: Budget and time")),
		26,
		UI.C_TEXT
	)
	main.add_child(heading)

	var intro: Label = UI.label(
		str(_pz.get("intro", "")),
		15,
		UI.C_MUTED
	)
	main.add_child(intro)

	_add_section_title(main, "1. Choose your construction approach")
	_add_build_options(main)

	_add_section_title(main, "2. Choose your testing approach")
	_add_test_options(main)

	_add_section_title(main, "3. Choose when to start the licence")

	_licence_label = UI.label("", 15, UI.C_CYAN)
	main.add_child(_licence_label)

	_licence_slider = HSlider.new()
	_licence_slider.min_value = float(_pz.get("licence_start_min", 0))
	_licence_slider.max_value = float(_pz.get("licence_start_max", 90))
	_licence_slider.step = float(_pz.get("licence_start_step", 5))
	_licence_slider.value = float(_licence_start)
	_licence_slider.value_changed.connect(_on_licence_changed)
	main.add_child(_licence_slider)

	_add_section_title(main, "Mission schedule")

	_chart = GanttChart.new()
	_chart.custom_minimum_size = Vector2(720, 260)
	_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(_chart)

	_result_label = UI.label("", 16, UI.C_TEXT, true)
	main.add_child(_result_label)

	_tip_bar = Chrome.tip_bar(str(_pz.get("lesson", "")))
	main.add_child(_tip_bar)


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var heading: Label = UI.label(text, 18, UI.C_CYAN)
	parent.add_child(heading)


func _add_build_options(parent: VBoxContainer) -> void:
	var options: Array = _pz.get("build_options", [])

	for item in options:
		var option: Dictionary = item
		var option_id: String = str(option.get("id", ""))
		var option_label: String = str(option.get("label", ""))
		var days: int = int(option.get("days", 0))
		var cost: float = float(option.get("cost_k", 0.0))

		var button: Button = Button.new()
		button.text = "%s — %d days — $%dk" % [
			option_label, days, int(cost)
		]
		button.pressed.connect(_on_build_selected.bind(option_id))
		parent.add_child(button)
		_build_buttons.append(button)


func _add_test_options(parent: VBoxContainer) -> void:
	var options: Array = _pz.get("test_options", [])

	for item in options:
		var option: Dictionary = item
		var option_id: String = str(option.get("id", ""))
		var option_label: String = str(option.get("label", ""))
		var days: int = int(option.get("days", 0))
		var cost: float = float(option.get("cost_k", 0.0))

		var button: Button = Button.new()
		button.text = "%s — %d days — $%dk" % [
			option_label, days, int(cost)
		]
		button.pressed.connect(_on_test_selected.bind(option_id))
		parent.add_child(button)
		_test_buttons.append(button)


func _on_build_selected(option_id: String) -> void:
	_build_id = option_id
	_update_screen()


func _on_test_selected(option_id: String) -> void:
	_test_id = option_id
	_update_screen()


func _on_licence_changed(value: float) -> void:
	_licence_start = int(value)
	_update_screen()


func _update_screen() -> void:
	if _pz.is_empty():
		return

	var result: Dictionary = Sim.puzzle_time(
		_pz,
		_build_id,
		_test_id,
		_licence_start
	)

	_chart.call(
		"set_data",
		result.get("bars", []),
		int(_pz.get("launch_day", 180))
	)

	_licence_label.text = "Licence application starts on day %d" % _licence_start

	var status: String = "PASS" if bool(result.get("passed", false)) else "NOT READY"

	var finish_day: int = int(result.get("finish_day", 0))
	var cost: float = float(result.get("cost_k", 0.0))
	var limit: float = float(result.get("cost_limit_k", 0.0))

	var message: String = "%s\nReady on day %d (launch deadline: day %d)\nCost: $%.0fk / $%.0fk allowed" % [
		status,
		finish_day,
		int(_pz.get("launch_day", 180)),
		cost,
		limit
	]

	var reasons: Array = result.get("reasons", [])

	for reason in reasons:
		message += "\n• " + str(reason)

	_result_label.text = message
	_update_button_styles()


func _update_button_styles() -> void:
	var build_options: Array = _pz.get("build_options", [])

	for i in range(_build_buttons.size()):
		var option: Dictionary = build_options[i]
		var button: Button = _build_buttons[i]
		button.modulate = Color.WHITE if str(option.get("id", "")) == _build_id else Color(0.7, 0.7, 0.7)

	var test_options: Array = _pz.get("test_options", [])

	for i in range(_test_buttons.size()):
		var option: Dictionary = test_options[i]
		var button: Button = _test_buttons[i]
		button.modulate = Color.WHITE if str(option.get("id", "")) == _test_id else Color(0.7, 0.7, 0.7)
