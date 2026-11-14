extends Control
## Puzzle 4: Budget and time. Plan the year on an interactive timeline:
## click the Build and Test bars to switch options, drag the Licence bar to choose when
## the paperwork starts. The satellite must be ready by launch day without overspending.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")
const PlanTimeline = preload("res://scripts/ui/plan_timeline.gd")

const ID: String = "time"

var _pz: Dictionary = {}
var _tip: Control = null
var _plan: Control = null
var _build_id: String = ""
var _test_id: String = ""
var _licence_start: int = 0
var _day_big: Label = null
var _cost_big: Label = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	var build_options: Array = _pz.get("build_options", [])
	var test_options: Array = _pz.get("test_options", [])
	if not build_options.is_empty():
		_build_id = str((build_options[0] as Dictionary).get("id", ""))
	if not test_options.is_empty():
		_test_id = str((test_options[0] as Dictionary).get("id", ""))
	_licence_start = int(_pz.get("licence_start_default", 60))
	add_child(Chrome.top_bar(str(_pz.get("title", "Puzzle 4: Budget and time")), ["Step 4 of 4"]))
	_tip = Chrome.tip_bar("Drag the orange Licence bar. Click the Build and Test bars to switch options.")
	add_child(_tip)
	_build_intro()
	_build_plan()
	_build_bottom()
	_refresh()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_intro() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(20, 84), Vector2(290, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	var intro: Label = UI.label(str(_pz.get("intro", "")), 14, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(262.0, 0.0)
	col.add_child(intro)
	col.add_child(UI.label("Why it is hard", 14, UI.C_ORANGE))
	col.add_child(UI.bullets(_pz.get("why_hard", []), 13, UI.C_TEXT, 262.0, UI.C_ORANGE))
	col.add_child(UI.label("Your goal", 14, UI.C_GREEN))
	col.add_child(UI.bullets(_pz.get("goal", []), 13, UI.C_TEXT, 262.0, UI.C_GREEN))


func _build_plan() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(326, 84), Vector2(934, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(24)
	col.add_child(head)
	head.add_child(UI.label("Your plan", 20))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_day_big = UI.label("", 18, UI.C_TEXT)
	head.add_child(_day_big)
	_cost_big = UI.label("", 18, UI.C_TEXT)
	head.add_child(_cost_big)
	_plan = PlanTimeline.new()
	_plan.custom_minimum_size = Vector2(906, 360)
	_plan.call("setup", _pz, _build_id, _test_id, _licence_start)
	_plan.connect("plan_changed", _on_plan_changed)
	col.add_child(_plan)


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


func _on_plan_changed(build_id: String, test_id: String, licence_start: int) -> void:
	if _locked:
		return
	_build_id = build_id
	_test_id = test_id
	_licence_start = licence_start
	_refresh()


func _refresh() -> void:
	var res: Dictionary = Sim.puzzle_time(_pz, _build_id, _test_id, _licence_start)
	_plan.call("set_result", res)
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	var launch_day: int = int(_pz.get("launch_day", 1))
	var finish: int = int(res.get("finish_day", 0))
	var cost: float = float(res.get("cost_k", 0.0))
	var limit: float = float(res.get("cost_limit_k", 1.0))
	_day_big.text = "Ready day %d / %d" % [finish, launch_day]
	_day_big.add_theme_color_override("font_color", UI.C_GREEN if finish <= launch_day else UI.C_RED)
	_cost_big.text = "%s / %s" % [UI.money(cost), UI.money(limit)]
	_cost_big.add_theme_color_override("font_color", UI.C_GREEN if cost <= limit + Sim.EPS else UI.C_RED)
	if passed:
		_message.text = "It works. " + str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
		Chrome.set_tip(_tip, "Ready in time and inside the budget. Press Lock it in.")
	else:
		_message.text = "  •  ".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
		Chrome.set_tip(_tip, "Watch the READY DAY line and the money bar as you drag the Licence bar.")
	_lock_btn.disabled = not passed or _locked


func _on_lock() -> void:
	if _locked:
		return
	_locked = true
	_lock_btn.disabled = true
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
