extends Control
## Puzzle 1: Mass. Load a photo satellite into a rocket slot.
## The rocket on the right shows every part you pick, stacked by weight, against the limit.
## Four limits at once (mass, money, power, data rate), so it takes some thinking.
## Layout: challenge left, part bin middle, rocket and readouts right, reasons below.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Sim = preload("res://scripts/core/sim.gd")
const PartCard = preload("res://scripts/ui/part_card.gd")
const RocketStack = preload("res://scripts/ui/rocket_stack.gd")

const ID: String = "mass"

var _pz: Dictionary = {}
var selected_ids: Array = []
var _cards: Dictionary = {}          # part id -> PartCard
var _rocket: Control = null
var _lines: Dictionary = {}          # "mass"/"cost"/"power"/"data" -> Label
var _checklist: VBoxContainer = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	_build_top_bar()
	_build_intro()
	_build_bin()
	_build_result()
	_build_bottom()
	_refresh()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label(str(_pz.get("title", "Puzzle")), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(40.0, 10.0)


func _build_intro() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(panel, Vector2(20, 88), Vector2(290, 470))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	var intro: Label = UI.label(str(_pz.get("intro", "")), 15, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(262.0, 0.0)
	col.add_child(intro)
	col.add_child(UI.label("Why it is hard", 14, UI.C_ORANGE))
	col.add_child(UI.bullets(_pz.get("why_hard", []), 13, UI.C_TEXT, 262.0, UI.C_ORANGE))
	col.add_child(UI.label("Your goal", 14, UI.C_GREEN))
	col.add_child(UI.bullets(_pz.get("goal", []), 13, UI.C_TEXT, 262.0, UI.C_GREEN))


func _build_bin() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(326, 88), Vector2(510, 470))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("Click a part to load it. Click again to take it out.", 13, UI.C_MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(488, 424)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var bin: Array = _pz.get("bin", [])
	for item in bin:
		var part_id: String = str(item)
		if not GameState.parts.has(part_id):
			continue
		var part: Dictionary = GameState.parts[part_id]
		var card: PanelContainer = PartCard.new()
		card.call("setup", part)
		card.connect("clicked", _on_toggle)
		grid.add_child(card)
		_cards[part_id] = card


func _build_result() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(852, 88), Vector2(408, 470))
	var row: HBoxContainer = UI.hbox(10)
	panel.add_child(row)
	_rocket = RocketStack.new()
	row.add_child(_rocket)
	var col: VBoxContainer = UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UI.label("Limits", 18))
	for key in ["mass", "cost", "power", "data"]:
		var l: Label = UI.label("", 14, UI.C_TEXT, true)
		l.custom_minimum_size = Vector2(196.0, 0.0)
		col.add_child(l)
		_lines[key] = l
	col.add_child(UI.label("Parts needed", 14, UI.C_MUTED))
	_checklist = UI.vbox(3)
	col.add_child(_checklist)


func _build_bottom() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(20, 566), Vector2(1240, 86))
	_message = UI.label("", 15, UI.C_RED, true)
	_message.custom_minimum_size = Vector2(1200.0, 0.0)
	panel.add_child(_message)
	_back_btn = UI.button("Back", _on_back, 160.0, false)
	_place(_back_btn, Vector2(20, 660), Vector2(160, 52))
	_lock_btn = UI.button("Lock it in", _on_lock, 220.0, true)
	_place(_lock_btn, Vector2(1040, 660), Vector2(220, 52))


func _on_toggle(part_id: String) -> void:
	if _locked:
		return
	if selected_ids.has(part_id):
		selected_ids.erase(part_id)
	else:
		selected_ids.append(part_id)
	GameState.play_sound("select")
	_refresh()


func _set_line(key: String, ok: bool, text: String) -> void:
	var l: Label = _lines[key]
	l.text = text + ("   OK" if ok else "   FAIL")
	l.add_theme_color_override("font_color", UI.C_GREEN if ok else UI.C_RED)


func _refresh() -> void:
	var res: Dictionary = Sim.puzzle_mass(_pz, GameState.parts, selected_ids)
	var mass: float = float(res.get("mass_kg", 0.0))
	var limit: float = maxf(0.001, float(res.get("limit_kg", 1.0)))
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	# the rocket picture: one block per chosen part
	var stack: Array = []
	for pid in selected_ids:
		var part: Dictionary = GameState.parts.get(str(pid), {})
		stack.append({"name": _short_name(part), "mass": float(part.get("mass_kg", 0.0)), "category": str(part.get("category", ""))})
	_rocket.call("set_load", stack, float(_pz.get("bus_kg", 0.0)), limit)
	# the four limits
	_set_line("mass", mass <= limit + Sim.EPS, "Mass %.2f of %.1f kg" % [mass, limit])
	var cost: float = float(res.get("cost_k", 0.0))
	var budget: float = float(res.get("budget_k", 0.0))
	_set_line("cost", budget <= 0.0 or cost <= budget + Sim.EPS, "Cost %s of %s" % [UI.money(cost), UI.money(budget)])
	var gen: float = float(res.get("gen_w", 0.0))
	var use: float = float(res.get("use_w", 0.0))
	_set_line("power", gen > 0.0 and gen >= use - Sim.EPS, "Power %.1f W made, %.1f W used" % [gen, use])
	var send: float = float(res.get("send_mb", 0.0))
	var need: float = float(res.get("need_send_mb", 0.0))
	_set_line("data", send >= need - Sim.EPS and send > 0.0, "Sends %d of %d MB a week" % [int(round(send)), int(round(need))])
	for key in _cards.keys():
		var card: PanelContainer = _cards[key]
		card.call("set_fitted", selected_ids.has(str(key)))
	_refresh_checklist(reasons)
	if passed:
		_message.text = "It fits and it works. " + str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
	elif selected_ids.is_empty():
		_message.text = "Start by loading the parts you think a photo satellite needs."
		_message.add_theme_color_override("font_color", UI.C_MUTED)
	else:
		_message.text = "  •  ".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
	_lock_btn.disabled = not passed or _locked


func _short_name(part: Dictionary) -> String:
	var n: String = str(part.get("name", ""))
	return n.replace("Small solar panels", "Small panels").replace("Large solar panels", "Large panels").replace("Standard battery", "Battery").replace("Small battery", "Sm. battery")


func _refresh_checklist(reasons: Array) -> void:
	UI.clear(_checklist)
	var needs: Array = _pz.get("needs", [])
	for item in needs:
		var need: Dictionary = item
		var ok: bool = not reasons.has(str(need.get("missing", "")))
		var text: String = _need_name(need) + (": loaded" if ok else ": missing")
		_checklist.add_child(UI.label(text, 14, UI.C_GREEN if ok else UI.C_MUTED))


func _need_name(need: Dictionary) -> String:
	var category: String = str(need.get("category", ""))
	if category == "instrument":
		return "Camera"
	if category == "solar":
		return "Solar panels"
	if category == "battery":
		return "Battery"
	if category == "radio":
		return "Radio"
	return category


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
	timer.wait_time = 1.6
	add_child(timer)
	timer.timeout.connect(_on_done)
	timer.start()


func _on_done() -> void:
	GameState.go("ladder")


func _on_back() -> void:
	if _locked:
		return
	GameState.go("ladder")
