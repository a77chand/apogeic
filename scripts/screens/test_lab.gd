extends Control
## Test lab: checks the design from the workshop against every requirement.
## Block 1 version: table, readiness meter, failure cards and buttons.
## On entry it shows the vibration_break event card once, applies the choice, then builds the table.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Data = preload("res://scripts/core/data.gd")
const EventCard = preload("res://scripts/ui/event_card.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

var _ev: Dictionary = {}
var _results: Array = []
var _launch: Dictionary = {}
var _leaving: bool = false
var _overlay: Control = null


func _ready() -> void:
	await _prelaunch_events()
	if not is_inside_tree():
		return
	_ev = GameState.evaluate()
	_results = Sim.check_requirements(GameState.level, _ev)
	_launch = Sim.can_launch(_ev, _results)
	_build_top_bar()
	_build_table()
	_build_side()
	_build_buttons()
	Tutorial.maybe_show(self, "test_lab")


## Shows each test-lab event that has not been seen yet, then applies the choice.
## This runs before the table is built, because a choice can change the schedule.
func _prelaunch_events() -> void:
	var part_ids: Array = GameState.evaluate().get("part_ids", [])
	var list: Array = Data.events_for(GameState.events, "test_lab", 0)
	for item in list:
		var event: Dictionary = item
		var id: String = str(event.get("id", ""))
		if GameState.events_seen.has(id):
			continue
		GameState.events_seen[id] = true
		var card: Control = EventCard.new()
		card.call("setup", event)
		add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var index: int = await card.chosen
		if not is_inside_tree():
			return
		var line: String = Sim.apply_prelaunch_choice(GameState.sched, part_ids, event, index)
		GameState.add_log(line)


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _any_failed() -> bool:
	return not Sim.all_passed(_results)


func _retest_days() -> int:
	var schedule: Dictionary = GameState.level.get("schedule", {})
	return int(schedule.get("retest_days", 10))


# ---------------------------------------------------------------- layout

func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	row.add_child(UI.label("Space Mission Designer", 16, UI.C_MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var title: Label = UI.label("Test lab", 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	var day: int = int(GameState.sched.get("day", 1))
	row.add_child(UI.label("Day %d" % day, 16, UI.C_CYAN))


func _build_table() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(900, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Test results", 20))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for head in ["Check", "What is tested", "Result", "Target", "Status"]:
		grid.add_child(UI.label(str(head), 13, UI.C_MUTED))
	for item in _results:
		var r: Dictionary = item
		var passed: bool = bool(r.get("passed", false))
		var color: Color = UI.C_GREEN
		if not passed:
			color = UI.C_RED
		grid.add_child(UI.label(str(r.get("id", "")), 15))
		var text: Label = UI.label(str(r.get("text", "")), 15, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(380.0, 0.0)
		grid.add_child(text)
		var unit: String = str(r.get("unit", ""))
		grid.add_child(UI.label(_fmt(float(r.get("value", 0.0)), unit), 15, color))
		grid.add_child(UI.label(_fmt(float(r.get("target", 0.0)), unit), 15, UI.C_MUTED))
		grid.add_child(_status_cell(passed, color))


func _status_cell(passed: bool, color: Color) -> Control:
	var h: HBoxContainer = UI.hbox(6)
	var icon_path: String = "res://art/icons/icon_status_red.png"
	if passed:
		icon_path = "res://art/icons/icon_status_green.png"
	if ResourceLoader.exists(icon_path):
		h.add_child(UI.picture(icon_path, Vector2(22, 22)))
	var word: String = "FAIL"
	if passed:
		word = "PASS"
	h.add_child(UI.label(word, 15, color))
	return h


## kg and % get one decimal. Everything else is a whole number.
func _fmt(value: float, unit: String) -> String:
	if unit == "kg" or unit == "%":
		return "%.1f %s" % [value, unit]
	return "%d %s" % [int(round(value)), unit]


func _build_side() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(940, 88), Vector2(320, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Readiness", 20))
	var ready: float = Sim.readiness_pct(_results)
	var bar: ProgressBar = UI.meter(280.0)
	var need: float = float(GameState.level.get("launch_min_readiness_pct", 80.0))
	UI.set_meter(bar, ready, UI.status_for(ready >= 99.99, ready >= need))
	col.add_child(bar)
	# a marker at 80%
	var marker: ColorRect = ColorRect.new()
	marker.color = UI.C_TEXT
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(marker)
	marker.position = Vector2(280.0 * need / 100.0, -3.0)
	marker.size = Vector2(2.0, 22.0)
	col.add_child(UI.label("%d%% ready. The rocket needs %d%% (the marker) to reach orbit." % [int(round(ready)), int(round(need))], 13, UI.C_MUTED, true))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(288.0, 340.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var cards: VBoxContainer = UI.vbox(8)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	var failed: int = 0
	for item in _results:
		var r: Dictionary = item
		if bool(r.get("passed", false)):
			continue
		failed += 1
		var card: PanelContainer = UI.panel(UI.C_RED, 10.0)
		card.custom_minimum_size = Vector2(270.0, 0.0)
		var inner: VBoxContainer = UI.vbox(4)
		card.add_child(inner)
		inner.add_child(UI.label(str(r.get("id", "")) + " failed", 14, UI.C_RED))
		var reason: Label = UI.label(str(r.get("reason", "")), 13, UI.C_TEXT, true)
		reason.custom_minimum_size = Vector2(240.0, 0.0)
		inner.add_child(reason)
		var tip: Label = UI.label("Tip: " + str(r.get("tip", "")), 13, UI.C_CYAN, true)
		tip.custom_minimum_size = Vector2(240.0, 0.0)
		inner.add_child(tip)
		cards.add_child(card)
	if failed == 0:
		cards.add_child(UI.label("Every check passed.", 15, UI.C_GREEN))


func _build_buttons() -> void:
	var back_text: String = "Back to workshop"
	if _any_failed():
		back_text = "Fix it (costs %d days)" % _retest_days()
	_place(UI.button(back_text, _on_back, 260.0, false), Vector2(20, 600), Vector2(260, 52))
	if not _any_failed():
		_place(UI.button("Launch", _on_launch, 220.0, true), Vector2(1040, 600), Vector2(220, 52))
		return
	var anyway: Button = UI.button("Launch anyway", _on_launch_anyway, 220.0, false)
	anyway.disabled = not bool(_launch.get("ok", false))
	_place(anyway, Vector2(1040, 600), Vector2(220, 52))
	if anyway.disabled:
		var why: Label = UI.label(str(_launch.get("reason", "")), 14, UI.C_RED, true)
		_place(why, Vector2(300, 600), Vector2(720, 52))


# ---------------------------------------------------------------- actions

func _on_back() -> void:
	if _leaving:
		return
	_leaving = true
	if _any_failed():
		GameState.sched["retests"] = int(GameState.sched.get("retests", 0)) + 1
	GameState.go("workshop")


func _on_launch() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.go("launch")


func _on_launch_anyway() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = overlay
	var centre: CenterContainer = CenterContainer.new()
	overlay.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_ORANGE, 20.0)
	panel.custom_minimum_size = Vector2(640.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("Launch with failed checks?", 24))
	var need: float = float(GameState.level.get("launch_min_readiness_pct", 80.0))
	if Sim.readiness_pct(_results) < need - Sim.EPS:
		col.add_child(UI.label("Only %d%% ready. Below %d%% the rocket will NOT reach orbit, and the mission ends at launch." % [int(round(Sim.readiness_pct(_results))), int(round(need))], 15, UI.C_RED, true))
	col.add_child(UI.label("These will happen in orbit:", 14, UI.C_MUTED))
	for item in _results:
		var r: Dictionary = item
		if bool(r.get("passed", false)):
			continue
		col.add_child(UI.label("%s: %s" % [str(r.get("id", "")), str(r.get("consequence", ""))], 15, UI.C_YELLOW, true))
	var row: HBoxContainer = UI.hbox(12)
	col.add_child(row)
	row.add_child(UI.button("Cancel", _on_cancel, 160.0, false))
	row.add_child(UI.button("Launch anyway", _on_confirm, 200.0, true))


func _on_cancel() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _on_confirm() -> void:
	_on_launch()
