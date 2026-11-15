extends Control
## NASA problem: an autonomous construction truck must sense obstacles, but no
## sensor works everywhere. Pick sensors, see detection in five conditions, and
## read why the truck misses things. All rules are in truck_sim.gd.

const UI = preload("res://scripts/ui/ui.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")

var _cfg: Dictionary = {}
var selected: Array = []
var _buttons: Dictionary = {}       # sensor id -> Button
var _cond_rows: Dictionary = {}     # condition id -> {"bar", "text", "status"}
var _limit_rows: Dictionary = {}    # "mass"/"power"/"cost" -> {"bar", "text"}
var _verdict: Label = null
var _causes: VBoxContainer = null
var _popup: Control = null


func _ready() -> void:
	_cfg = TruckSim.load_config()
	_build_top_bar()
	_build_sensors()
	_build_conditions()
	_build_limits()
	_build_explain()
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
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	row.add_child(UI.label("NASA problem: autonomous construction truck", 16, UI.C_MUTED))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UI.label(str(_cfg.get("title", "Can the truck see?")), 28))
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	row.add_child(UI.label("MOSTLY ILLUSTRATIVE NUMBERS", 12, UI.C_ORANGE))


func _build_sensors() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(20, 88), Vector2(410, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("Choose the truck's sensors", 20))
	var list: Array = _cfg.get("sensors", [])
	for item in list:
		var s: Dictionary = item
		var id: String = str(s.get("id", ""))
		var tag: String = "   [NASA data]" if _has_sourced(s) else ""
		var text: String = "%s%s   (%.1f kg, %d W, $%dk)\n%s" % [
				str(s.get("name", id)), tag, float(s.get("mass_kg", 0.0)), int(float(s.get("power_w", 0.0))),
				int(float(s.get("cost_k", 0.0))), str(s.get("blurb", ""))]
		var b: Button = UI.button(text, Callable(), 380.0, false)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(380.0, 44.0)
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		b.add_theme_stylebox_override("pressed", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 4, 6.0))
		b.add_theme_stylebox_override("hover_pressed", UI.box(UI.C_HOVER.lightened(0.1), UI.C_GREEN, 16, 4, 6.0))
		b.toggled.connect(_on_toggled.bind(id))
		col.add_child(b)
		_buttons[id] = b


func _build_conditions() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(446, 88), Vector2(420, 430))
	var col: VBoxContainer = UI.vbox(4)
	panel.add_child(col)
	col.add_child(UI.label("Does it see the obstacle?", 20))
	var target: float = float(_cfg.get("target_detect_pct", 95.0))
	col.add_child(UI.label("Needs %d%% in every condition." % int(target), 12, UI.C_MUTED))
	var list: Array = _cfg.get("conditions", [])
	for item in list:
		var c: Dictionary = item
		var id: String = str(c.get("id", ""))
		var head: HBoxContainer = UI.hbox(6)
		var name_label: Label = UI.label(str(c.get("name", id)), 14, UI.C_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var value: Label = UI.label("", 14)
		head.add_child(value)
		var status: Label = UI.label("", 14)
		status.custom_minimum_size = Vector2(52.0, 0.0)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(status)
		col.add_child(head)
		var bar: ProgressBar = UI.meter(390.0)
		bar.custom_minimum_size = Vector2(390.0, 12.0)
		col.add_child(bar)
		var why: Label = UI.label(str(c.get("why", "")), 11, UI.C_MUTED, true)
		why.custom_minimum_size = Vector2(390.0, 0.0)
		col.add_child(why)
		_cond_rows[id] = {"bar": bar, "text": value, "status": status}


func _build_limits() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(882, 88), Vector2(378, 430))
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	col.add_child(UI.label("What the truck can carry", 20))
	for key in ["mass", "power", "cost"]:
		var title: String = {"mass": "Mass", "power": "Power", "cost": "Budget"}[key]
		col.add_child(UI.label(title, 14, UI.C_MUTED))
		var bar: ProgressBar = UI.meter(350.0)
		col.add_child(bar)
		var text: Label = UI.label("", 13)
		col.add_child(text)
		_limit_rows[key] = {"bar": bar, "text": text}
	_verdict = UI.label("", 18, UI.C_TEXT, true)
	_verdict.custom_minimum_size = Vector2(350.0, 0.0)
	col.add_child(_verdict)


func _build_explain() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 10.0)
	_place(panel, Vector2(20, 530), Vector2(1240, 120))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_causes = UI.vbox(3)
	_causes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_causes)
	var back: Button = UI.button("Back to home", _on_back, 200.0, false)
	_place(back, Vector2(20, 660), Vector2(200, 52))
	var note: Label = UI.label(str(_cfg.get("fusion_note", "")), 11, UI.C_MUTED, true)
	_place(note, Vector2(240, 662), Vector2(740, 50))
	_place(UI.button("Where is the data from?", _on_sources, 270.0, true), Vector2(990, 660), Vector2(270, 52))


func _on_toggled(pressed: bool, id: String) -> void:
	if pressed and not selected.has(id):
		selected.append(id)
	elif not pressed:
		selected.erase(id)
	_refresh()


func _refresh() -> void:
	var res: Dictionary = TruckSim.evaluate(_cfg, selected)
	var conditions: Array = res.get("conditions", [])
	for item in conditions:
		var c: Dictionary = item
		var row: Dictionary = _cond_rows[str(c["id"])]
		var passed: bool = bool(c["passed"])
		var pct: float = float(c["detect_pct"])
		var close: bool = pct < float(_cfg.get("target_detect_pct", 95.0)) + 3.0
		UI.set_meter(row["bar"], pct, UI.status_for(passed, close))
		var value: Label = row["text"]
		value.text = "%.1f%%" % pct
		var status: Label = row["status"]
		status.text = "OK" if passed else "Miss"
		status.add_theme_color_override("font_color", UI.C_GREEN if passed else UI.C_RED)
	var limits: Dictionary = _cfg.get("limits", {})
	_set_limit("mass", float(res["mass_kg"]), float(limits.get("mass_kg", 1.0)), bool(res["mass_ok"]), "%.1f kg of %.1f kg")
	_set_limit("power", float(res["power_w"]), float(limits.get("power_w", 1.0)), bool(res["power_ok"]), "%d W of %d W")
	_set_limit("cost", float(res["cost_k"]), float(limits.get("budget_k", 1.0)), bool(res["cost_ok"]), "$%dk of $%dk")
	UI.clear(_causes)
	if selected.is_empty():
		_verdict.text = "Pick at least one sensor."
		_verdict.add_theme_color_override("font_color", UI.C_MUTED)
		_causes.add_child(UI.label(str(_cfg.get("intro", "")), 14, UI.C_TEXT, true))
		_causes.add_child(UI.label("Why it matters: " + str(_cfg.get("lesson", "")), 14, UI.C_CYAN, true))
	elif bool(res["passed"]):
		_verdict.text = "The truck sees everything it needs to."
		_verdict.add_theme_color_override("font_color", UI.C_GREEN)
		_causes.add_child(UI.label(str(_cfg.get("lesson", "")), 14, UI.C_GREEN, true))
	else:
		_verdict.text = "The truck would miss obstacles."
		_verdict.add_theme_color_override("font_color", UI.C_RED)
		var causes: Array = res.get("causes", [])
		for line in causes:
			_causes.add_child(UI.label("- " + str(line), 13, UI.C_YELLOW, true))


func _set_limit(key: String, value: float, limit: float, ok: bool, fmt: String) -> void:
	var row: Dictionary = _limit_rows[key]
	UI.set_meter(row["bar"], value / maxf(0.001, limit) * 100.0, UI.status_for(ok, value >= limit * 0.9))
	var text: Label = row["text"]
	if key == "mass":
		text.text = fmt % [value, limit]
	else:
		text.text = fmt % [int(round(value)), int(round(limit))]


## True if any of this sensor's numbers come from a real source (not a placeholder).
func _has_sourced(sensor: Dictionary) -> bool:
	var basis: Dictionary = sensor.get("detect_basis", {})
	for key in basis:
		if str(basis[key]) == "sourced":
			return true
	return false


## A popup that says which numbers are real and which are illustrative, with the sources.
func _on_sources() -> void:
	if _popup != null and is_instance_valid(_popup):
		return
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup = overlay
	var centre: CenterContainer = CenterContainer.new()
	overlay.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 18.0)
	panel.custom_minimum_size = Vector2(1000.0, 560.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Where do these numbers come from?", 24, UI.C_CYAN))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(960.0, 440.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body: VBoxContainer = UI.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_para("Honest summary: no published study gives detection rates for these sensors in these Moon conditions, so most numbers here are illustrative. Only the structured-light sensor uses real NASA numbers, and only for sunlit, shadowed and dark conditions. The ranking (radar best in dust, lidar and cameras hurt by dust, cameras blind in the dark) is supported by the sources below. The exact percentages are not.", UI.C_YELLOW, 14))
	body.add_child(UI.label("Each sensor", 16, UI.C_MUTED))
	var sensors: Array = _cfg.get("sensors", [])
	for item in sensors:
		var s: Dictionary = item
		body.add_child(_para("%s: %s" % [str(s.get("name", "")), str(s.get("basis_note", ""))], UI.C_TEXT, 13))
	body.add_child(UI.label("Sources", 16, UI.C_MUTED))
	var evidence: Array = _cfg.get("evidence", [])
	for item in evidence:
		var e: Dictionary = item
		body.add_child(_para("[%s] %s" % [str(e.get("kind", "")), str(e.get("title", ""))], UI.C_CYAN, 13))
		body.add_child(_para(str(e.get("supports", "")), UI.C_TEXT, 12))
		body.add_child(_para(str(e.get("url", "")), UI.C_MUTED, 11))
	col.add_child(UI.button("Close", _on_close_sources, 160.0, true))


func _para(text: String, color: Color, size: int) -> Label:
	var l: Label = UI.label(text, size, color, true)
	l.custom_minimum_size = Vector2(930.0, 0.0)
	return l


func _on_close_sources() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _on_back() -> void:
	GameState.go("title")
