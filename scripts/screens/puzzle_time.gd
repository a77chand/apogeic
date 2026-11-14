extends Control
## Puzzle 4: Budget and time. Pick a build, a test and a licence start day so the
## satellite is ready by launch day without overspending.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")
const GanttChart = preload("res://scripts/ui/gantt_chart.gd")

const ID: String = "time"

var _pz: Dictionary = {}
var _tip: Control = null
var _chart: Control = null
var _build_id: String = ""
var _test_id: String = ""
var _build_buttons: Dictionary = {}   # option id -> Button
var _test_buttons: Dictionary = {}
var _licence_slider: HSlider = null
var _licence_label: Label = null
var _ready_bar: ProgressBar = null
var _ready_label: Label = null
var _cost_bar: ProgressBar = null
var _cost_label: Label = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	var build_options: Array = _pz.get("build_options", [])
	var test_options: Array = _pz.get("test_options", [])
	if not build_options.is_empty():
		var first_build: Dictionary = build_options[0]
		_build_id = str(first_build.get("id", ""))
	if not test_options.is_empty():
		var first_test: Dictionary = test_options[0]
		_test_id = str(first_test.get("id", ""))
	add_child(Chrome.top_bar(str(_pz.get("title", "Puzzle 4: Budget and time")), ["Step 4 of 4"]))
	_tip = Chrome.tip_bar("Pick a build, a test, and when to start the licence paperwork.")
	add_child(_tip)
	_build_intro()
	_build_middle()
	_build_result()
	_build_bottom()
	_refresh()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_intro() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(20, 84), Vector2(280, 430))
	var col: VBoxContainer = UI.vbox(12)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	var intro: Label = UI.label(str(_pz.get("intro", "")), 15, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(248.0, 0.0)
	col.add_child(intro)
	var facts: String = "Budget %s, and %d%% of it must stay in reserve. The team costs %s every day. The licence takes %d days." % [
			UI.money(float(_pz.get("budget_k", 0.0))), int(round(float(_pz.get("reserve_pct", 0.0)))),
			UI.money(float(_pz.get("staff_cost_k_per_day", 0.0))), int(_pz.get("licence_days", 0))]
	var fact_label: Label = UI.label(facts, 13, UI.C_MUTED, true)
	fact_label.custom_minimum_size = Vector2(248.0, 0.0)
	col.add_child(fact_label)


func _choice_button(option: Dictionary, on_press: Callable) -> Button:
	var text: String = "%s\n%d days, %s" % [str(option.get("label", "")), int(option.get("days", 0)), UI.money(float(option.get("cost_k", 0.0)))]
	var b: Button = UI.button(text, on_press, 290.0, false)
	b.custom_minimum_size = Vector2(290.0, 52.0)
	return b


func _build_middle() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(316, 84), Vector2(640, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	_chart = GanttChart.new()
	col.add_child(_chart)
	col.add_child(UI.label("Build", 14, UI.C_MUTED))
	var build_row: HBoxContainer = UI.hbox(12)
	col.add_child(build_row)
	var build_options: Array = _pz.get("build_options", [])
	for item in build_options:
		var option: Dictionary = item
		var id: String = str(option.get("id", ""))
		var b: Button = _choice_button(option, _on_build.bind(id))
		build_row.add_child(b)
		_build_buttons[id] = b
	col.add_child(UI.label("Testing", 14, UI.C_MUTED))
	var test_row: HBoxContainer = UI.hbox(12)
	col.add_child(test_row)
	var test_options: Array = _pz.get("test_options", [])
	for item in test_options:
		var option: Dictionary = item
		var id: String = str(option.get("id", ""))
		var b: Button = _choice_button(option, _on_test.bind(id))
		test_row.add_child(b)
		_test_buttons[id] = b
	_licence_label = UI.label("", 14)
	col.add_child(_licence_label)
	_licence_slider = HSlider.new()
	_licence_slider.min_value = float(_pz.get("licence_start_min", 0))
	_licence_slider.max_value = float(_pz.get("licence_start_max", 90))
	_licence_slider.step = float(_pz.get("licence_start_step", 5))
	_licence_slider.set_value_no_signal(float(_pz.get("licence_start_default", 60)))
	_licence_slider.custom_minimum_size = Vector2(500.0, 24.0)
	_licence_slider.focus_mode = Control.FOCUS_NONE
	_licence_slider.value_changed.connect(_on_slider)
	col.add_child(_licence_slider)


func _build_result() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(972, 84), Vector2(288, 430))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Result", 20))
	col.add_child(UI.label("Ready on day", 14, UI.C_MUTED))
	_ready_bar = UI.meter(250.0)
	col.add_child(_ready_bar)
	_ready_label = UI.label("", 14)
	col.add_child(_ready_label)
	col.add_child(UI.label("Cost", 14, UI.C_MUTED))
	_cost_bar = UI.meter(250.0)
	col.add_child(_cost_bar)
	_cost_label = UI.label("", 14)
	col.add_child(_cost_label)


func _build_bottom() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(20, 522), Vector2(1240, 70))
	_message = UI.label("", 15, UI.C_RED, true)
	_message.custom_minimum_size = Vector2(1200.0, 0.0)
	panel.add_child(_message)
	_back_btn = UI.button("Back", _on_back, 160.0, false)
	_place(_back_btn, Vector2(20, 598), Vector2(160, 52))
	_lock_btn = UI.button("Lock it in", _on_lock, 220.0, true)
	_place(_lock_btn, Vector2(1040, 598), Vector2(220, 52))


func _on_build(id: String) -> void:
	if _locked:
		return
	_build_id = id
	_refresh()


func _on_test(id: String) -> void:
	if _locked:
		return
	_test_id = id
	_refresh()


func _on_slider(_value: float) -> void:
	if _locked:
		return
	_refresh()


## The selected option uses the primary (brighter) style.
func _style_choice(b: Button, selected: bool) -> void:
	var fill: Color = UI.C_PANEL
	var border: Color = UI.C_BORDER
	if selected:
		fill = UI.C_HOVER
		border = UI.C_CYAN
	b.add_theme_stylebox_override("normal", UI.box(fill, border))
	b.add_theme_stylebox_override("hover", UI.box(fill.lightened(0.1), UI.C_CYAN))
	b.add_theme_stylebox_override("pressed", UI.box(UI.C_DEEP, UI.C_CYAN))


func _refresh() -> void:
	for key in _build_buttons.keys():
		_style_choice(_build_buttons[key], str(key) == _build_id)
	for key in _test_buttons.keys():
		_style_choice(_test_buttons[key], str(key) == _test_id)
	var licence_start: int = int(_licence_slider.value)
	var licence_days: int = int(_pz.get("licence_days", 0))
	_licence_label.text = "Start the licence paperwork on day %d (it takes %d days, so it is done on day %d)" % [licence_start, licence_days, licence_start + licence_days]
	var res: Dictionary = Sim.puzzle_time(_pz, _build_id, _test_id, licence_start)
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	var launch_day: int = int(_pz.get("launch_day", 1))
	var finish: int = int(res.get("finish_day", 0))
	var cost: float = float(res.get("cost_k", 0.0))
	var limit: float = maxf(0.001, float(res.get("cost_limit_k", 1.0)))
	_chart.call("set_data", res.get("bars", []), launch_day)
	# ready day
	var day_ok: bool = finish <= launch_day
	var day_close: bool = float(finish) >= float(launch_day) * 0.9
	UI.set_meter(_ready_bar, float(finish) / float(maxi(1, launch_day)) * 100.0, UI.status_for(day_ok, day_close))
	_ready_label.text = "Day %d of %d  %s" % [finish, launch_day, _word(day_ok, day_close)]
	# cost
	var cost_ok: bool = cost <= limit + Sim.EPS
	var cost_close: bool = cost >= limit * 0.9
	UI.set_meter(_cost_bar, cost / limit * 100.0, UI.status_for(cost_ok, cost_close))
	_cost_label.text = "%s of %s  %s" % [UI.money(cost), UI.money(limit), _word(cost_ok, cost_close)]
	if passed:
		_message.text = str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
		Chrome.set_tip(_tip, "It works. Press Lock it in.")
	else:
		_message.text = "\n".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
		Chrome.set_tip(_tip, "Look at the orange Licence bar. Starting it earlier might help.")
	_lock_btn.disabled = not passed or _locked


func _word(ok: bool, close: bool) -> String:
	if not ok:
		return "Fail"
	if close:
		return "Close"
	return "OK"


func _on_lock() -> void:
	if _locked:
		return
	_locked = true
	_lock_btn.disabled = true
	GameState.mark_puzzle_done(ID)
	GameState.play_sound("chime")
	_message.text = str(_pz.get("lesson", ""))
	_message.add_theme_color_override("font_color", UI.C_GREEN)
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.4
	add_child(timer)
	timer.timeout.connect(_on_done)
	timer.start()


func _on_done() -> void:
	GameState.go("ladder")


func _on_back() -> void:
	if _locked:
		return
	GameState.go("ladder")
