extends Control
## Puzzle 1: Mass. Pick parts from a bin without going over the rocket limit.
## Layout: intro left, toggle cards middle, live result right, reasons / lesson below.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const PartCard = preload("res://scripts/ui/part_card.gd")

const ID: String = "mass"

var _pz: Dictionary = {}
var selected_ids: Array = []
var _cards: Dictionary = {}          # part id -> PartCard
var _mass_bar: ProgressBar = null
var _mass_label: Label = null
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
	bar.add_theme_stylebox_override("panel", UI.box(UI.C_DEEP, UI.C_BORDER, 0, 2, 12.0))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label(str(_pz.get("title", "Puzzle")), 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)


func _build_intro() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(300, 470))
	var col: VBoxContainer = UI.vbox(12)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	var intro: Label = UI.label(str(_pz.get("intro", "")), 15, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(264.0, 0.0)
	col.add_child(intro)
	var hint: Label = UI.label("Click a part to add it. Click again to take it out.", 13, UI.C_MUTED, true)
	hint.custom_minimum_size = Vector2(264.0, 0.0)
	col.add_child(hint)


func _build_bin() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(336, 88), Vector2(520, 470))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
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
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(872, 88), Vector2(388, 470))
	var row: HBoxContainer = UI.hbox(16)
	panel.add_child(row)
	row.add_child(UI.picture("res://art/modules/rocket_small.png", Vector2(110, 330), "rocket"))
	var col: VBoxContainer = UI.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UI.label("Mass", 18))
	_mass_bar = UI.meter(200.0)
	col.add_child(_mass_bar)
	_mass_label = UI.label("", 14)
	col.add_child(_mass_label)
	col.add_child(UI.label("You need:", 16, UI.C_MUTED))
	_checklist = UI.vbox(6)
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
	_refresh()


func _refresh() -> void:
	var res: Dictionary = Sim.puzzle_mass(_pz, GameState.parts, selected_ids)
	var mass: float = float(res.get("mass_kg", 0.0))
	var limit: float = maxf(0.001, float(res.get("limit_kg", 1.0)))
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	var under: bool = mass <= limit + Sim.EPS
	UI.set_meter(_mass_bar, mass / limit * 100.0, UI.status_for(under, mass >= limit * 0.9))
	var word: String = "OK"
	if not under:
		word = "Fail"
	_mass_label.text = "%.2f kg of %.1f kg  (%s)" % [mass, limit, word]
	for key in _cards.keys():
		var card: PanelContainer = _cards[key]
		card.call("set_fitted", selected_ids.has(str(key)))
	_refresh_checklist(reasons)
	if passed:
		_message.text = str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		_message.text = "\n".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
	_lock_btn.disabled = not passed or _locked


func _refresh_checklist(reasons: Array) -> void:
	UI.clear(_checklist)
	var needs: Array = _pz.get("needs", [])
	for item in needs:
		var need: Dictionary = item
		var ok: bool = not reasons.has(str(need.get("missing", "")))
		var text: String = "[ ] " + _need_name(need)
		var color: Color = UI.C_MUTED
		if ok:
			text = "[x] " + _need_name(need)
			color = UI.C_GREEN
		_checklist.add_child(UI.label(text, 14, color))


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
