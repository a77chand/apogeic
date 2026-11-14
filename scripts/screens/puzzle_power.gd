extends Control
## Puzzle 2: Power. Size the panels and the battery so the satellite survives the eclipse.
## Layout: intro left, chart and sliders middle, live result right, reasons / lesson below.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")
const LineChart = preload("res://scripts/ui/line_chart.gd")
const Film = preload("res://scripts/ui/film.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

const ID: String = "power"

var _pz: Dictionary = {}
var _bar: Control = null
var _tip: Control = null
var _chart: Control = null
var _panel_slider: HSlider = null
var _battery_slider: HSlider = null
var _panel_label: Label = null
var _battery_label: Label = null
var _min_bar: ProgressBar = null
var _min_label: Label = null
var _end_label: Label = null
var _mass_bar: ProgressBar = null
var _mass_label: Label = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	_bar = Chrome.top_bar(str(_pz.get("title", "Puzzle 2: Power")), ["Step 2 of 4"])
	add_child(_bar)
	_tip = Chrome.tip_bar("Drag the sliders. The line shows the battery charge through one orbit.")
	add_child(_tip)
	_build_intro()
	_build_middle()
	_build_result()
	_build_bottom()
	_refresh()
	Tutorial.maybe_show(self, "puzzle_power")


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_intro() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(20, 84), Vector2(280, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	var intro: Label = UI.label(str(_pz.get("intro", "")), 15, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(248.0, 0.0)
	col.add_child(intro)
	col.add_child(UI.button("▶  Watch: a dead battery", _on_watch, 250.0, false))
	col.add_child(UI.bullets(["Needs 12 W, day and night", "Dark for 35 of every 95 minutes"], 14, UI.C_TEXT, 250.0, UI.C_ORANGE))
	col.add_child(UI.label("Your goal", 14, UI.C_GREEN))
	col.add_child(UI.bullets(_pz.get("goal", []), 14, UI.C_TEXT, 250.0, UI.C_GREEN))


func _make_slider(min_v: float, max_v: float, step: float, start: float) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.set_value_no_signal(start)
	s.custom_minimum_size = Vector2(500.0, 24.0)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(_on_slider)
	return s


func _build_middle() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(316, 84), Vector2(640, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	_chart = LineChart.new()
	col.add_child(_chart)
	_panel_label = UI.label("", 15)
	col.add_child(_panel_label)
	_panel_slider = _make_slider(float(_pz.get("panel_min_w", 0.0)), float(_pz.get("panel_max_w", 10.0)),
			float(_pz.get("panel_step_w", 1.0)), float(_pz.get("panel_start_w", 0.0)))
	col.add_child(_panel_slider)
	_battery_label = UI.label("", 15)
	col.add_child(_battery_label)
	_battery_slider = _make_slider(float(_pz.get("battery_min_wh", 0.0)), float(_pz.get("battery_max_wh", 10.0)),
			float(_pz.get("battery_step_wh", 1.0)), float(_pz.get("battery_start_wh", 0.0)))
	col.add_child(_battery_slider)


func _build_result() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(972, 84), Vector2(288, 430))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Result", 20))
	col.add_child(UI.label("Lowest battery level", 14, UI.C_MUTED))
	_min_bar = UI.meter(250.0)
	col.add_child(_min_bar)
	_min_label = UI.label("", 14)
	col.add_child(_min_label)
	_end_label = UI.label("", 14, UI.C_MUTED, true)
	col.add_child(_end_label)
	col.add_child(UI.label("Mass", 14, UI.C_MUTED))
	_mass_bar = UI.meter(250.0)
	col.add_child(_mass_bar)
	_mass_label = UI.label("", 14)
	col.add_child(_mass_label)


func _build_bottom() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(20, 522), Vector2(1240, 70))
	_message = UI.label("", 15, UI.C_RED, true)
	_message.custom_minimum_size = Vector2(1200.0, 0.0)
	panel.add_child(_message)
	_back_btn = UI.button("Back", _on_back, 160.0, false)
	_place(_back_btn, Vector2(20, 598), Vector2(160, 52))
	_lock_btn = UI.button("Fly one orbit", _on_lock, 220.0, true)
	_place(_lock_btn, Vector2(1040, 598), Vector2(220, 52))


func _on_slider(_value: float) -> void:
	if _locked:
		return
	_refresh()


func _refresh() -> void:
	var panel_w: float = _panel_slider.value
	var battery_wh: float = _battery_slider.value
	var res: Dictionary = Sim.puzzle_power(_pz, panel_w, battery_wh)
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	var min_pct: float = float(res.get("min_pct", 0.0))
	var min_level: float = float(_pz.get("min_level_pct", 0.0))
	var mass: float = float(res.get("mass_kg", 0.0))
	var mass_limit: float = maxf(0.001, float(_pz.get("mass_limit_kg", 1.0)))
	_panel_label.text = "Solar panels: %d W average" % int(round(panel_w))
	_battery_label.text = "Battery: %d Wh" % int(round(battery_wh))
	_chart.call("set_data", res.get("points", []), float(_pz.get("eclipse_min", 0.0)), float(_pz.get("period_min", 1.0)), min_level)
	# lowest level
	var level_ok: bool = battery_wh > 0.0 and min_pct >= min_level - Sim.EPS
	UI.set_meter(_min_bar, min_pct, UI.status_for(level_ok, min_pct < min_level * 1.1))
	var level_word: String = "OK"
	if not level_ok:
		level_word = "Fail"
	elif min_pct < min_level * 1.1:
		level_word = "Close"
	_min_label.text = "%d%% (needs %d%% or more)  %s" % [int(round(min_pct)), int(round(min_level)), level_word]
	_end_label.text = "At the end of the orbit: %d%%" % int(round(float(res.get("end_pct", 0.0))))
	# mass
	var mass_ok: bool = mass <= mass_limit + Sim.EPS
	UI.set_meter(_mass_bar, mass / mass_limit * 100.0, UI.status_for(mass_ok, mass >= mass_limit * 0.9))
	var mass_word: String = "OK"
	if not mass_ok:
		mass_word = "Fail"
	elif mass >= mass_limit * 0.9:
		mass_word = "Close"
	_mass_label.text = "%.2f kg of %.2f kg  %s" % [mass, mass_limit, mass_word]
	# message
	if passed:
		_message.text = str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
		Chrome.set_tip(_tip, "Looks good. Press Fly one orbit to try it.")
	else:
		_message.text = "\n".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
		Chrome.set_tip(_tip, "Drag the sliders. The line shows the battery charge through one orbit.")
	_lock_btn.disabled = _locked


func _on_watch() -> void:
	Film.play(self, "power_fail", ["Every orbit, the Earth hides the Sun for 35 minutes.", "If the battery is too small, it runs flat in the dark and the satellite goes silent."])


func _on_lock() -> void:
	if _locked:
		return
	var res: Dictionary = Sim.puzzle_power(_pz, _panel_slider.value, _battery_slider.value)
	_locked = true
	_lock_btn.disabled = true
	if not bool(res.get("passed", false)):
		var lines: Array = ["The battery fell to %d%% in the dark." % int(round(float(res.get("min_pct", 0.0))))]
		if float(res.get("mass_kg", 0.0)) > float(_pz.get("mass_limit_kg", 1.0)) + Sim.EPS:
			lines = ["The panels and battery are too heavy for the satellite (%.2f kg)." % float(res.get("mass_kg", 0.0)), "The rocket would refuse it. Here is what a too-small battery looks like instead."]
		lines.append("Bigger panels refill the battery faster in sunlight; a bigger battery lasts longer in the dark.")
		var film: Control = Film.play(self, "power_fail", lines)
		await film.finished
		_locked = false
		_refresh()
		return
	var ok: Control = Film.play(self, "power_ok", ["The battery dips in the dark, then the panels fill it again.", str(_pz.get("lesson", ""))])
	await ok.finished
	GameState.mark_puzzle_done(ID)
	GameState.play_sound("fanfare")
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
