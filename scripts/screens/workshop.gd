extends Control
## Workshop: the main screen. Fit parts (click or drag), watch six live bars.
## Block 1: tray, click-to-fit, slot rows, live bars, readiness, Test it.
## Block 2 (not here yet): clock, pause, Why red?, drag polish.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const PartCard = preload("res://scripts/ui/part_card.gd")
const DropZone = preload("res://scripts/ui/drop_zone.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

# bar id -> {"req": requirement id, "bar": ProgressBar, "text": Label, "status": Label}
var _bars: Dictionary = {}
var _slot_col: VBoxContainer = null
var _cards: Dictionary = {}          # part id -> PartCard
var _readiness_bar: ProgressBar = null
var _readiness_label: Label = null
var _tip: Label = null
var _day_pill: Label = null
var _money_pill: Label = null
var _tray: ScrollContainer = null
var _pause_btn: Button = null
var _paused: bool = false
var _popup: Control = null          # the open "Why red?" popup, if any
var _acc: float = 0.0               # seconds collected towards the next day
var _base_tip: String = ""
const MAX_DAY: int = 250


## The clock. A day passes every seconds_per_day. Stops while paused or while a popup is open.
func _process(delta: float) -> void:
	if _paused or GameState.tutorial_open or (_popup != null and is_instance_valid(_popup)):
		return
	var schedule: Dictionary = GameState.level.get("schedule", {})
	var per_day: float = maxf(0.1, float(schedule.get("seconds_per_day", 2.0)))
	_acc += delta
	var moved: bool = false
	while _acc >= per_day:
		_acc -= per_day
		var day: int = int(GameState.sched.get("day", 1))
		if day >= MAX_DAY:
			_acc = 0.0
			break
		GameState.sched["day"] = day + 1
		moved = true
	if moved:
		_refresh()


func _ready() -> void:
	_build_top_bar()
	_build_left_panel()
	_build_centre()
	_build_right_panel()
	_build_tray()
	_build_tip_bar()
	GameState.design_changed.connect(_refresh)
	_set_tip("Click a part below to fit it, or drag it onto the satellite.")
	_refresh()
	Tutorial.maybe_show(self, "workshop")


# ---------------------------------------------------------------- layout

func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	row.add_child(UI.label("Space Mission Designer", 16, UI.C_MUTED))
	var spacer_a: Control = Control.new()
	spacer_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_a)
	var title: Label = UI.label("Workshop", 28)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var spacer_b: Control = Control.new()
	spacer_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer_b)
	_day_pill = UI.label("", 16, UI.C_CYAN)
	_money_pill = UI.label("", 16, UI.C_GREEN)
	var help_btn: Button = UI.button("Help", _on_help, 80.0, false)
	help_btn.custom_minimum_size = Vector2(80.0, 40.0)
	row.add_child(help_btn)
	row.add_child(_pill(_day_pill))
	row.add_child(_pill(_money_pill))


func _pill(inner: Label) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.C_PANEL, UI.C_BORDER, 16, 2, 8.0))
	p.add_child(inner)
	return p


func _build_left_panel() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(20, 88), Vector2(290, 420))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("On your satellite", 20))
	_slot_col = UI.vbox(8)
	col.add_child(_slot_col)


func _build_centre() -> void:
	var zone: DropZone = DropZone.new()
	zone.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 20, 2, 12.0))
	_place(zone, Vector2(326, 88), Vector2(600, 420))
	zone.part_dropped.connect(_on_fit_any)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(centre)
	var col: VBoxContainer = UI.vbox(8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(col)
	col.add_child(UI.picture("res://art/modules/cubesat_3u.png", Vector2(560, 187), "CubeSat body (drop parts here)"))
	var hint: Label = UI.label("Drop parts here, or click them below", 14, UI.C_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint)


func _build_right_panel() -> void:
	# This panel must stay 420 px tall (spec 12.9), or the readiness meter ends up
	# hidden behind the tray. So spacing, bar height and text size are kept small.
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(942, 88), Vector2(318, 420))
	var col: VBoxContainer = UI.vbox(2)
	panel.add_child(col)
	col.add_child(UI.label("Checks", 18))
	# bar key, title, requirement id
	var defs: Array = [
		["mass", "Mass", "R1"],
		["power", "Power", "R3"],
		["eclipse", "Battery in eclipse", "R5"],
		["data", "Data", "R2"],
		["budget", "Budget", "R4"],
		["time", "Time", "R6"],
	]
	for item in defs:
		var def: Array = item
		var key: String = str(def[0])
		var head: HBoxContainer = UI.hbox(6)
		var title: Label = UI.label(str(def[1]), 13, UI.C_MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var status: Label = UI.label("", 13, UI.C_TEXT)
		head.add_child(status)
		col.add_child(head)
		var bar: ProgressBar = UI.meter(290.0)
		bar.custom_minimum_size = Vector2(290.0, 10.0)
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.mouse_entered.connect(_on_bar_hover.bind(key))
		bar.mouse_exited.connect(_rest_tip)
		col.add_child(bar)
		var text: Label = UI.label("", 12, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(290.0, 0.0)
		col.add_child(text)
		_bars[key] = {"req": str(def[2]), "bar": bar, "text": text, "status": status}
	_readiness_bar = UI.meter(290.0)
	_readiness_bar.custom_minimum_size = Vector2(290.0, 10.0)
	col.add_child(_readiness_bar)
	_readiness_label = UI.label("", 14)
	col.add_child(_readiness_label)


func _build_tray() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	_tray = scroll
	_place(scroll, Vector2(20, 520), Vector2(1030, 110))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var row: HBoxContainer = UI.hbox(8)
	scroll.add_child(row)
	var order: Array = GameState.parts.keys()
	for key in order:
		var part: Dictionary = GameState.parts[key]
		var card: PanelContainer = PartCard.new()
		card.call("setup", part)
		card.connect("clicked", _on_fit_any)
		card.connect("hovered", _on_card_hover)
		card.connect("unhovered", _rest_tip)
		row.add_child(card)
		_cards[str(part.get("id", ""))] = card
	var why_btn: Button = UI.button("Why red?", _on_why_red, 190.0, false)
	why_btn.custom_minimum_size = Vector2(190.0, 36.0)
	_place(why_btn, Vector2(1070, 518), Vector2(190, 36))
	_pause_btn = UI.button("Pause", _on_pause, 190.0, false)
	_pause_btn.custom_minimum_size = Vector2(190.0, 36.0)
	_place(_pause_btn, Vector2(1070, 560), Vector2(190, 36))
	var test_btn: Button = UI.button("Test it", _on_test, 190.0, true)
	_place(test_btn, Vector2(1070, 604), Vector2(190, 50))


func _build_tip_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	var row: HBoxContainer = UI.hbox(12)
	bar.add_child(row)
	_tip = UI.label("", 15)
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tip)
	row.add_child(UI.label("PLACEHOLDER NUMBERS", 12, UI.C_ORANGE))


# ---------------------------------------------------------------- behaviour

## A message that stays until the next action.
func _set_tip(text: String) -> void:
	_base_tip = text
	if _tip != null:
		_tip.text = text


## A hover message. It goes back to the last stay-put message when the mouse leaves.
func _hover_tip(text: String) -> void:
	if _tip != null:
		_tip.text = text


func _rest_tip() -> void:
	if _tip != null:
		_tip.text = _base_tip


func _on_card_hover(part_id: String) -> void:
	if not GameState.parts.has(part_id):
		return
	var part: Dictionary = GameState.parts[part_id]
	_hover_tip("%s: %s Click to fit it." % [str(part.get("name", part_id)), str(part.get("blurb", ""))])


## Click or drop: find the slot for the part's category, then fit it.
func _on_fit_any(part_id: String) -> void:
	if not GameState.parts.has(part_id):
		return
	var part: Dictionary = GameState.parts[part_id]
	var category: String = str(part.get("category", ""))
	var slot_id: String = category
	if category == "extra":
		if str(GameState.design.get("extra_a", "")) == "":
			slot_id = "extra_a"
		elif str(GameState.design.get("extra_b", "")) == "":
			slot_id = "extra_b"
		else:
			_set_tip("Both extra slots are full. Remove one first.")
			return
	_fit(slot_id, part_id)


## A part dropped on a specific slot row.
func _on_row_dropped(part_id: String, slot_id: String) -> void:
	_fit(slot_id, part_id)


func _fit(slot_id: String, part_id: String) -> void:
	if _is_fitted(part_id):
		_set_tip("That part is already fitted.")
		return
	if GameState.set_slot(slot_id, part_id):
		var part: Dictionary = GameState.parts[part_id]
		_set_tip("Fitted: %s." % str(part.get("name", part_id)))
	else:
		_set_tip("That part is already fitted.")


func _on_remove(slot_id: String) -> void:
	GameState.set_slot(slot_id, "")
	_set_tip("Removed.")


func _on_test() -> void:
	GameState.go("test_lab")


func _on_pause() -> void:
	_paused = not _paused
	if _paused:
		_pause_btn.text = "Resume"
		_tray.modulate = Color(1, 1, 1, 0.45)
		_set_tip("Paused. The day counter and the budget are frozen.")
	else:
		_pause_btn.text = "Pause"
		_tray.modulate = Color(1, 1, 1, 1)
		_set_tip("Running.")


## A popup that lists the reason and tip of every failing check.
func _on_why_red() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	var ev: Dictionary = GameState.evaluate()
	var results: Array = Sim.check_requirements(GameState.level, ev)
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup = overlay
	var centre: CenterContainer = CenterContainer.new()
	overlay.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_ORANGE, 20.0)
	panel.custom_minimum_size = Vector2(640.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("Why red?", 24))
	var any_fail: bool = false
	for item in results:
		var r: Dictionary = item
		if bool(r.get("passed", false)):
			continue
		any_fail = true
		col.add_child(UI.label(str(r.get("text", "")), 16, UI.C_YELLOW, true))
		col.add_child(UI.label(str(r.get("reason", "")), 14, UI.C_TEXT, true))
		col.add_child(UI.label("Tip: " + str(r.get("tip", "")), 14, UI.C_CYAN, true))
	if not any_fail:
		col.add_child(UI.label("Nothing is red. Every check passes.", 16, UI.C_GREEN, true))
	col.add_child(UI.button("Close", _on_close_popup, 160.0, true))


## How to play the workshop, in plain words.
func _on_help() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup = overlay
	var centre: CenterContainer = CenterContainer.new()
	overlay.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 20.0)
	panel.custom_minimum_size = Vector2(640.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("How the workshop works", 24))
	var lines: Array = [
		"1. Click a part in the tray (or drag it onto the satellite) to fit it.",
		"2. Click X on a slot to take a part out. Required slots show yellow when empty.",
		"3. Watch the six bars. Red means a check fails. Hover a bar to see why.",
		"4. Time is money: every day of building costs staff pay and pushes launch later.",
		"5. Pause stops the clock. Why red? lists every problem with a tip.",
		"6. Press Test it when you are ready. A failed test costs 10 days.",
	]
	for line in lines:
		col.add_child(UI.label(str(line), 15, UI.C_TEXT, true))
	col.add_child(UI.button("Close", _on_close_popup, 160.0, true))


func _on_close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _on_bar_hover(key: String) -> void:
	var entry: Dictionary = _bars[key]
	var ev: Dictionary = GameState.evaluate()
	var results: Array = Sim.check_requirements(GameState.level, ev)
	var r: Dictionary = Sim.result_by_id(results, str(entry["req"]))
	if r.is_empty():
		return
	if bool(r.get("passed", false)):
		_hover_tip(str(r.get("text", "")))
	else:
		_hover_tip("%s %s" % [str(r.get("reason", "")), str(r.get("tip", ""))])


func _status_of(r: Dictionary) -> String:
	if r.is_empty():
		return "red"
	var passed: bool = bool(r.get("passed", false))
	var value: float = float(r.get("value", 0.0))
	var target: float = float(r.get("target", 0.0))
	var close: bool = false
	if str(r.get("id", "")) in ["R1", "R6"]:
		close = value >= target * 0.9  # a maximum, so "close" is near the top
	else:
		close = value <= target * 1.1  # a minimum, so "close" is near the floor
	return UI.status_for(passed, close)


func _word_for(status: String) -> String:
	if status == "red":
		return "Fail"
	if status == "yellow":
		return "Close"
	return "OK"


func _color_for(status: String) -> Color:
	if status == "red":
		return UI.C_RED
	if status == "yellow":
		return UI.C_YELLOW
	return UI.C_GREEN


func _set_bar(key: String, percent: float, text: String, results: Array) -> void:
	var entry: Dictionary = _bars[key]
	var r: Dictionary = Sim.result_by_id(results, str(entry["req"]))
	var status: String = _status_of(r)
	UI.set_meter(entry["bar"], percent, status)
	var text_label: Label = entry["text"]
	text_label.text = text
	var status_label: Label = entry["status"]
	status_label.text = _word_for(status)
	status_label.add_theme_color_override("font_color", _color_for(status))


func _refresh() -> void:
	var ev: Dictionary = GameState.evaluate()
	var results: Array = Sim.check_requirements(GameState.level, ev)
	var limits: Dictionary = GameState.level.get("limits", {})
	var mass_limit: float = float(limits.get("mass_kg", 1.0))
	var budget: float = float(limits.get("budget_k", 1.0))
	var deadline: float = float(limits.get("deadline_day", 1.0))
	var gen: float = float(ev.get("power_gen_w", 0.0))
	var use: float = float(ev.get("power_use_w", 0.0))
	var mass: float = float(ev.get("mass_kg", 0.0))
	var delivered: float = float(ev.get("delivered_mb_wk", 0.0))
	var made: float = float(ev.get("make_mb_wk", 0.0))
	var sent: float = float(ev.get("send_mb_wk", 0.0))
	var launch_day: float = float(ev.get("launch_day", 0.0))
	var total: float = float(ev.get("total_cost_k", 0.0))
	var data_target: float = float(Sim.result_by_id(results, "R2").get("target", 1.0))

	_set_bar("mass", mass / mass_limit * 100.0,
			"%.1f kg of %.1f kg" % [mass, mass_limit], results)
	var power_fill: float = 100.0
	if gen > 0.0:
		power_fill = use / gen * 100.0
	_set_bar("power", power_fill, "%.1f W used of %.1f W" % [use, gen], results)
	_set_bar("eclipse", float(ev.get("eclipse_min_pct", 0.0)),
			"lowest %d%%" % int(round(float(ev.get("eclipse_min_pct", 0.0)))), results)
	_set_bar("data", delivered / data_target * 100.0,
			"%d of %d MB/wk delivered (makes %d, sends %d)" % [int(round(delivered)), int(round(data_target)), int(round(made)), int(round(sent))], results)
	_set_bar("budget", total / budget * 100.0,
			"%s of %s" % [UI.money(total), UI.money(budget)], results)
	_set_bar("time", launch_day / deadline * 100.0,
			"launch day %d of %d" % [int(round(launch_day)), int(round(deadline))], results)

	var ready: float = Sim.readiness_pct(results)
	UI.set_meter(_readiness_bar, ready, UI.status_for(ready >= 99.99, ready >= 80.0))
	_readiness_label.text = "%d%% ready" % int(round(ready))

	_day_pill.text = "Day %d of %d" % [int(GameState.sched.get("day", 1)), int(deadline)]
	_money_pill.text = "%s left" % UI.money(float(ev.get("money_left_k", 0.0)))

	_refresh_slots()
	for key in _cards.keys():
		var card: PanelContainer = _cards[key]
		card.call("set_fitted", _is_fitted(str(key)))


func _is_fitted(part_id: String) -> bool:
	for slot_id in GameState.design.keys():
		if str(GameState.design[slot_id]) == part_id:
			return true
	return false


func _refresh_slots() -> void:
	UI.clear(_slot_col)
	var slot_list: Array = GameState.level.get("slots", [])
	for item in slot_list:
		var slot: Dictionary = item
		var slot_id: String = str(slot.get("id", ""))
		var part_id: String = str(GameState.design.get(slot_id, ""))
		var zone: DropZone = DropZone.new()
		zone.accept_category = str(slot.get("category", ""))
		zone.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_DISABLED_BORDER, 10, 1, 6.0))
		zone.part_dropped.connect(_on_row_dropped.bind(slot_id))
		_slot_col.add_child(zone)
		var row: HBoxContainer = UI.hbox(6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(row)
		var col: VBoxContainer = UI.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var head: Label = UI.label(str(slot.get("label", slot_id)), 12, UI.C_MUTED)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		if part_id == "":
			var color: Color = UI.C_MUTED
			if bool(slot.get("required", false)):
				color = UI.C_YELLOW
			var empty: Label = UI.label("empty", 15, color)
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(empty)
		else:
			var part: Dictionary = GameState.parts.get(part_id, {})
			var name_label: Label = UI.label(str(part.get("name", part_id)), 15)
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(name_label)
			var rm: Button = UI.button("X", _on_remove.bind(slot_id), 36.0, false)
			rm.custom_minimum_size = Vector2(36.0, 36.0)
			rm.tooltip_text = "Remove"
			row.add_child(rm)
