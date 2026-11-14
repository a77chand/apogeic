extends Control
## Puzzle 3: Data link. The camera makes more than the radio can send.
## Switch fixes on or off and watch Made, Sent and Delivered.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")

const ID: String = "link"

var _pz: Dictionary = {}
var selected_option_ids: Array = []
var _option_buttons: Dictionary = {}   # option id -> Button
var _bars: Dictionary = {}             # "make"/"send"/"delivered" -> {"bar", "text"}
var _spare_mass_label: Label = null
var _spare_mass_bar: ProgressBar = null
var _spare_cost_label: Label = null
var _spare_cost_bar: ProgressBar = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	_build_top_bar()
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


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
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
	var hint: Label = UI.label("Switch the fixes on and off. The bars show where the photos get stuck.", 13, UI.C_MUTED, true)
	hint.custom_minimum_size = Vector2(264.0, 0.0)
	col.add_child(hint)


func _build_middle() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(336, 88), Vector2(520, 470))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	# picture strip: satellite, dotted arc, ground station
	var strip: HBoxContainer = UI.hbox(8)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(strip)
	strip.add_child(UI.picture("res://art/modules/cubesat_3u.png", Vector2(150, 60), "satellite"))
	var arc: Label = UI.label("- - - - - - - >", 20, UI.C_CYAN)
	arc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.add_child(arc)
	strip.add_child(UI.picture("res://art/modules/ground_station.png", Vector2(70, 70), "ground station"))
	# three bars
	var defs: Array = [["make", "Made"], ["send", "Sent capacity"], ["delivered", "Delivered"]]
	for item in defs:
		var def: Array = item
		var key: String = str(def[0])
		var head: HBoxContainer = UI.hbox(8)
		var name_label: Label = UI.label(str(def[1]), 14, UI.C_MUTED)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var text: Label = UI.label("", 13)
		head.add_child(text)
		col.add_child(head)
		var bar: ProgressBar = UI.meter(470.0)
		col.add_child(bar)
		_bars[key] = {"bar": bar, "text": text}
	# option toggles
	var options: Array = _pz.get("options", [])
	for item in options:
		var opt: Dictionary = item
		var id: String = str(opt.get("id", ""))
		var b: Button = UI.button("%s\n%s" % [str(opt.get("label", id)), str(opt.get("detail", ""))], Callable(), 470.0, false)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(470.0, 48.0)
		b.add_theme_stylebox_override("pressed", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 4))
		b.add_theme_stylebox_override("hover_pressed", UI.box(UI.C_HOVER.lightened(0.1), UI.C_GREEN, 16, 4))
		b.toggled.connect(_on_option_toggled.bind(id))
		col.add_child(b)
		_option_buttons[id] = b


func _build_result() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(872, 88), Vector2(388, 470))
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("What you have left", 20))
	col.add_child(UI.label("Spare mass used", 14, UI.C_MUTED))
	_spare_mass_bar = UI.meter(340.0)
	col.add_child(_spare_mass_bar)
	_spare_mass_label = UI.label("", 14)
	col.add_child(_spare_mass_label)
	col.add_child(UI.label("Spare money used", 14, UI.C_MUTED))
	_spare_cost_bar = UI.meter(340.0)
	col.add_child(_spare_cost_bar)
	_spare_cost_label = UI.label("", 14)
	col.add_child(_spare_cost_label)


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


func _on_option_toggled(pressed: bool, id: String) -> void:
	if _locked:
		return
	if pressed and not selected_option_ids.has(id):
		selected_option_ids.append(id)
	elif not pressed:
		selected_option_ids.erase(id)
	_refresh()


func _set_flow_bar(key: String, value: float, need: float, ok: bool) -> void:
	var entry: Dictionary = _bars[key]
	var close: bool = value <= need * 1.1
	UI.set_meter(entry["bar"], value / maxf(1.0, need) * 100.0, UI.status_for(ok, close))
	var text: Label = entry["text"]
	text.text = "%d MB/wk  (need %d)" % [int(round(value)), int(round(need))]


func _refresh() -> void:
	var res: Dictionary = Sim.puzzle_link(_pz, selected_option_ids)
	var need: float = float(_pz.get("need_mb_wk", 1.0))
	var make: float = float(res.get("make", 0.0))
	var send: float = float(res.get("send", 0.0))
	var delivered: float = float(res.get("delivered", 0.0))
	var mass: float = float(res.get("mass_kg", 0.0))
	var cost: float = float(res.get("cost_k", 0.0))
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	_set_flow_bar("make", make, need, make >= need - Sim.EPS)
	_set_flow_bar("send", send, need, send >= need - Sim.EPS)
	_set_flow_bar("delivered", delivered, need, delivered >= need - Sim.EPS)
	var spare_mass: float = float(_pz.get("spare_mass_kg", 1.0))
	var spare_cost: float = float(_pz.get("spare_cost_k", 1.0))
	var mass_ok: bool = mass <= spare_mass + Sim.EPS
	var cost_ok: bool = cost <= spare_cost + Sim.EPS
	UI.set_meter(_spare_mass_bar, mass / maxf(0.001, spare_mass) * 100.0, UI.status_for(mass_ok, mass >= spare_mass * 0.9))
	UI.set_meter(_spare_cost_bar, cost / maxf(0.001, spare_cost) * 100.0, UI.status_for(cost_ok, cost >= spare_cost * 0.9))
	_spare_mass_label.text = "%.1f kg of %.1f kg  (%s)" % [mass, spare_mass, "OK" if mass_ok else "Fail"]
	_spare_cost_label.text = "%s of %s  (%s)" % [UI.money(cost), UI.money(spare_cost), "OK" if cost_ok else "Fail"]
	if passed:
		_message.text = str(_pz.get("lesson", ""))
		_message.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		_message.text = "\n".join(PackedStringArray(reasons))
		_message.add_theme_color_override("font_color", UI.C_RED)
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
