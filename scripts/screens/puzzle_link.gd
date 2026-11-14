extends Control
## Puzzle 3: Data link, as an idea board. The camera makes more than the radio can send.
## Nine ideas are on the board: some work, some are traps, some only work together.
## Switch ideas on and off and watch the pipeline: the narrowest pipe is the bottleneck.
## Any answer that fits the spare mass, money and power passes; the cleverest one is free.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Sim = preload("res://scripts/core/sim.gd")
const DataPipe = preload("res://scripts/ui/data_pipe.gd")

const ID: String = "link"

var _pz: Dictionary = {}
var selected_option_ids: Array = []
var _option_buttons: Dictionary = {}   # option id -> Button
var _pipe: Control = null
var _meters: Dictionary = {}           # "mass"/"cost"/"power" -> {"bar", "text"}
var _idea_note: Label = null
var _message: Label = null
var _lock_btn: Button = null
var _back_btn: Button = null
var _locked: bool = false


func _ready() -> void:
	_pz = GameState.puzzles.get(ID, {})
	_build_top_bar()
	_build_intro()
	_build_pipe()
	_build_board()
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
	_place(panel, Vector2(20, 88), Vector2(300, 470))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("The challenge", 20))
	col.add_child(UI.bullets([
		"Camera makes: %d MB/wk" % int(_pz.get("make_mb_wk", 0)),
		"Radio sends: %d MB/wk" % int(_pz.get("send_mb_wk", 0)),
		"Goal: %d MB/wk to the ground" % int(_pz.get("need_mb_wk", 0)),
	], 15, UI.C_TEXT, 272.0))
	col.add_child(UI.label("Each card: what it adds, then its cost.", 12, UI.C_MUTED, true))
	col.add_child(UI.label("What you have spare", 14, UI.C_MUTED))
	for item in [["mass", "Mass"], ["cost", "Money"], ["power", "Power"]]:
		var pair: Array = item
		var row: HBoxContainer = UI.hbox(6)
		col.add_child(row)
		var name_label: Label = UI.label(str(pair[1]), 13, UI.C_MUTED)
		name_label.custom_minimum_size = Vector2(52.0, 0.0)
		row.add_child(name_label)
		var bar: ProgressBar = UI.meter(110.0)
		bar.custom_minimum_size = Vector2(110.0, 10.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var text: Label = UI.label("", 13)
		row.add_child(text)
		_meters[str(pair[0])] = {"bar": bar, "text": text}


func _build_pipe() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(336, 88), Vector2(924, 150))
	_pipe = DataPipe.new()
	_pipe.custom_minimum_size = Vector2(900, 126)
	panel.add_child(_pipe)


func _build_board() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(336, 246), Vector2(924, 312))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(10)
	col.add_child(head)
	head.add_child(UI.label("Idea board", 18))
	_idea_note = UI.label("Switch ideas on and off. Try combining them.", 13, UI.C_MUTED)
	_idea_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_idea_note.clip_text = true
	head.add_child(_idea_note)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for item in _pz.get("options", []):
		var opt: Dictionary = item
		var id: String = str(opt.get("id", ""))
		var b: Button = UI.button("%s\n%s" % [str(opt.get("label", id)), _card_numbers(opt)], Callable(), 294.0, false)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(294.0, 78.0)
		b.add_theme_font_size_override("font_size", 14)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var on: StyleBoxFlat = UI.chunky(Color(0.10, 0.30, 0.22), UI.C_GREEN, true)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.toggled.connect(_on_option_toggled.bind(id))
		grid.add_child(b)
		_option_buttons[id] = b


## The numbers on an idea card, short and in the same order on every card so they line up:
## effect first, then mass, money and power.
func _card_numbers(opt: Dictionary) -> String:
	var bits: Array = []
	if float(opt.get("add_send", 0.0)) > 0.0:
		bits.append("+%d sent" % int(opt.get("add_send", 0.0)))
	if float(opt.get("set_make", -1.0)) >= 0.0:
		bits.append("camera %d" % int(opt.get("set_make", 0.0)))
	var pw: float = float(opt.get("power_w", 0.0))
	if bits.is_empty() and pw < 0.0:
		bits.append("frees %d W" % int(-pw))
	bits.append("%.1f kg" % float(opt.get("mass_kg", 0.0)) if float(opt.get("mass_kg", 0.0)) > 0.0 else "0 kg")
	bits.append(UI.money(float(opt.get("cost_k", 0.0))) if float(opt.get("cost_k", 0.0)) > 0.0 else "free")
	if pw > 0.0:
		bits.append("%d W" % int(pw))
	return "• " + "  • ".join(PackedStringArray(bits))


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


func _option(id: String) -> Dictionary:
	for item in _pz.get("options", []):
		var opt: Dictionary = item
		if str(opt.get("id", "")) == id:
			return opt
	return {}


func _on_option_toggled(pressed: bool, id: String) -> void:
	if _locked:
		return
	if pressed and not selected_option_ids.has(id):
		selected_option_ids.append(id)
	elif not pressed:
		selected_option_ids.erase(id)
	GameState.play_sound("select")
	if pressed:
		_idea_note.text = str(_option(id).get("why", ""))
		_idea_note.add_theme_color_override("font_color", UI.C_ACCENT)
	_refresh()


func _set_meter(key: String, used: float, spare: float, text: String) -> void:
	var entry: Dictionary = _meters[key]
	var ok: bool = used <= spare + Sim.EPS
	UI.set_meter(entry["bar"], used / maxf(0.001, spare) * 100.0, UI.status_for(ok, used >= spare * 0.9))
	var l: Label = entry["text"]
	l.text = text
	l.add_theme_color_override("font_color", UI.C_TEXT if ok else UI.C_RED)


func _refresh() -> void:
	var res: Dictionary = Sim.puzzle_link(_pz, selected_option_ids)
	var need: float = float(_pz.get("need_mb_wk", 1.0))
	var make: float = float(res.get("make", 0.0))
	var send: float = float(res.get("send", 0.0))
	var delivered: float = float(res.get("delivered", 0.0))
	var mass: float = float(res.get("mass_kg", 0.0))
	var cost: float = float(res.get("cost_k", 0.0))
	var power: float = float(res.get("power_w", 0.0))
	var passed: bool = bool(res.get("passed", false))
	var reasons: Array = res.get("reasons", [])
	_pipe.call("set_flow", make, send, delivered, need)
	var spare_mass: float = float(_pz.get("spare_mass_kg", 1.0))
	var spare_cost: float = float(_pz.get("spare_cost_k", 1.0))
	var spare_power: float = float(_pz.get("spare_power_w", 1.0))
	_set_meter("mass", mass, spare_mass, "%.1f / %.1f kg" % [mass, spare_mass])
	_set_meter("cost", cost, spare_cost, "%s / %s" % [UI.money(cost), UI.money(spare_cost)])
	_set_meter("power", maxf(0.0, power), spare_power, "%d / %d W" % [int(round(power)), int(round(spare_power))])
	if passed:
		var best: float = float(_pz.get("best_cost_k", 0.0))
		var line: String = "It works: %d MB a week reach the ground, for %s." % [int(round(delivered)), UI.money(cost)]
		if cost <= best + Sim.EPS:
			line += " Engineer's pick: that is the cheapest answer there is!"
		else:
			line += " Lock it in, or look for an answer that costs nothing (hint: power)."
		_message.text = line
		_message.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		_message.text = "  •  ".join(PackedStringArray(reasons))
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
	timer.wait_time = 1.8
	add_child(timer)
	timer.timeout.connect(_on_done)
	timer.start()


func _on_done() -> void:
	GameState.go("ladder")


func _on_back() -> void:
	if _locked:
		return
	GameState.go("ladder")
