extends Control
## Briefing: the goal, the concept chips (locked ones say why), and what must be hit.
## Chips do not change the game in Level 1; they show the reasoning.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Craft = preload("res://scripts/core/craft.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

var _tip: Label = null


func _ready() -> void:
	_build_top_bar()
	_build_mission()
	_build_concept()
	_build_requirements()
	_build_bottom()
	Tutorial.maybe_show(self, "briefing")


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Briefing", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(14.0, 14.0)


func _build_mission() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(400, 480))
	var col: VBoxContainer = UI.vbox(7)
	panel.add_child(col)
	col.add_child(UI.label(str(GameState.level.get("level_label", "")), 13, UI.C_MUTED))
	col.add_child(UI.label(str(GameState.level.get("name", "")), 24, UI.C_CYAN))
	col.add_child(UI.based_on_tag(GameState.level))
	var pic: Control = UI.picture("res://art/modules/cubesat_%s.png" % GameState.craft_id, Vector2(360, 80), "CubeSat " + GameState.craft_id.to_upper())
	col.add_child(pic)
	var goal: Label = UI.label(str(GameState.level.get("goal_text", "")), 15, UI.C_TEXT, true)
	goal.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(goal)
	var limits: Dictionary = GameState.level.get("limits", {})
	var words: String = "Limits: at most %.1f kg, a budget of %s, and launch by day %d." % [
			float(limits.get("mass_kg", 0.0)), UI.money(float(limits.get("budget_k", 0.0))), int(float(limits.get("deadline_day", 0.0)))]
	var limit_label: Label = UI.label(words, 14, UI.C_YELLOW, true)
	limit_label.custom_minimum_size = Vector2(360.0, 0.0)
	col.add_child(limit_label)
	var diffs: Array = GameState.level.get("differences", [])
	if not diffs.is_empty():
		col.add_child(UI.label("The real story", 14, UI.C_ORANGE))
		col.add_child(UI.bullets(diffs, 13, UI.C_TEXT, 360.0, UI.C_ORANGE))


func _build_concept() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(436, 88), Vector2(420, 480))
	var col: VBoxContainer = UI.vbox(5)
	panel.add_child(col)
	col.add_child(UI.label("Your concept", 20))
	var chips: Array = GameState.level.get("concept_chips", [])
	var groups: Array = []
	for item in chips:
		var chip: Dictionary = item
		var group: String = str(chip.get("group", ""))
		if not groups.has(group):
			groups.append(group)
	for group_name in groups:
		# the group name, with a few words on what the term means
		var head: HBoxContainer = UI.hbox(8)
		col.add_child(head)
		head.add_child(UI.label(str(group_name), 14, UI.C_MUTED))
		var gloss: String = str(GLOSSARY.get(str(group_name), ""))
		if str(group_name) == "Spacecraft" and not GameState.is_cubesat_mission():
			gloss = "a real satellite, not a CubeSat"
		head.add_child(UI.label(gloss, 12, Color(UI.C_ACCENT, 0.85)))
		if str(group_name) == "Spacecraft" and GameState.is_cubesat_mission() and GameState.craft_sizes().size() > 1:
			col.add_child(_craft_row())  # a CubeSat mission offers the sizes the real ones came in
			continue
		var row: HFlowContainer = HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.custom_minimum_size = Vector2(380.0, 0.0)
		col.add_child(row)
		for item in chips:
			var chip: Dictionary = item
			if str(chip.get("group", "")) != str(group_name) or str(chip.get("state", "")) == "locked":
				continue   # options that do not apply to this mission are not shown
			row.add_child(_chip(chip))
	_build_facts(col)


## A few words for each term in the concept, so "3U" or "rideshare" is not a buzzword.
const GLOSSARY: Dictionary = {
	"Spacecraft": "CubeSat: built from 10 cm cubes. 1U = one cube",
	"Orbit": "the path it circles Earth on",
	"Launch": "how it gets to space",
}


## 1U / 3U / 6U buttons. The chosen one is highlighted; pressing another reloads this screen.
func _craft_row() -> Control:
	var row: HBoxContainer = UI.hbox(8)
	for id in GameState.craft_sizes():
		var b: Button = UI.button(str(id).to_upper(), _on_craft.bind(str(id)), 10.0, false)
		b.custom_minimum_size = Vector2(70.0, 40.0)
		if str(id) == GameState.craft_id:
			b.add_theme_stylebox_override("normal", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 3, 8.0))
			b.add_theme_stylebox_override("hover", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 3, 8.0))
		row.add_child(b)
	# the chosen size drawn as cubes: 1U one cube, 3U three in a stack, 6U two stacks
	var cubes: Control = Control.new()
	cubes.custom_minimum_size = Vector2(70.0, 40.0)
	cubes.tooltip_text = "Each cube is 10 x 10 x 10 cm (one \"U\")"
	cubes.mouse_filter = Control.MOUSE_FILTER_PASS
	cubes.draw.connect(_draw_cubes.bind(cubes))
	row.add_child(cubes)
	return row


func _draw_cubes(c: Control) -> void:
	var n: int = int(GameState.craft_id.to_int())
	var cols: int = 2 if n >= 6 else 1
	var rows: int = maxi(1, n / cols)
	var u: float = minf(12.0, 36.0 / float(rows))
	var x0: float = 8.0
	var y0: float = c.size.y - 2.0
	for cx in range(cols):
		for cy in range(rows):
			var r: Rect2 = Rect2(Vector2(x0 + float(cx) * (u + 2.0), y0 - float(cy + 1) * (u + 1.0)), Vector2(u, u))
			c.draw_rect(r, Color(0.85, 0.75, 0.45))
			c.draw_rect(r, Color(0.35, 0.28, 0.12), false, 1.0)
	c.draw_string(ThemeDB.fallback_font, Vector2(x0 + float(cols) * (u + 2.0) + 4.0, y0 - 4.0), "%d x 10 cm" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.C_MUTED)


func _build_facts(col: VBoxContainer) -> void:
	if not GameState.is_cubesat_mission():
		var sat: Dictionary = GameState.base_level.get("satellite_class", {})
		col.add_child(UI.label("About this spacecraft", 14, UI.C_MUTED))
		var lines: Array = [
			"%s, %s in real life" % [str(sat.get("name", "Satellite")), str(sat.get("real_mass", ""))],
			"Its parts are listed in the tray; parts it never had are left out",
		]
		for line in lines:
			var l: Label = UI.label(str(line), 13, UI.C_TEXT, true)
			l.custom_minimum_size = Vector2(380.0, 0.0)
			col.add_child(l)
		var note: Label = UI.label("In the game the parts and limits are scaled to a small model, so every mission plays the same way.", 11, UI.C_MUTED, true)
		note.custom_minimum_size = Vector2(380.0, 0.0)
		col.add_child(note)
		return
	var craft: Dictionary = Craft.by_id(GameState.craft_cfg, GameState.craft_id)
	if craft.is_empty():
		return
	col.add_child(UI.label("About the %s" % str(craft.get("name", "")), 14, UI.C_MUTED))
	var dim: Array = craft.get("dimension_cm", {}).get("value", [])
	var dim_words: String = " x ".join(PackedStringArray(dim.map(func(v): return _num(float(v)))))
	var power: Dictionary = craft.get("peak_power_w", {})
	var cost: Dictionary = craft.get("launch_cost_k", {})
	var down: Dictionary = craft.get("downlink_kbps", {})
	var game: Dictionary = craft.get("game", {})
	var lines: Array = [
		"Size: %s cm" % dim_words,
		"Mass limit here: %s kg" % _num(float(game.get("mass_limit_kg", 0.0))),
		"Peak power: %s W" % _range(power, 1.0, ""),
		"Launch cost: %s (this mission pays %s)" % [UI.money(float(cost.get("min", 0.0))) + " to " + UI.money(float(cost.get("max", 0.0))), UI.money(float((GameState.level.get("launch", {}) as Dictionary).get("cost_k", 0.0)))],
		"Data downlink: %s" % (_rate(float(down.get("min", 0.0))) + " to " + _rate(float(down.get("max", 0.0)))),
	]
	for line in lines:
		var l: Label = UI.label(str(line), 13, UI.C_TEXT, true)
		l.custom_minimum_size = Vector2(380.0, 0.0)
		col.add_child(l)
	var note: Label = UI.label("Size and mass limit: CubeSat Design Specification Rev 14.1. The game uses the older, tighter mass limit. Power, cost and data rate are typical ranges.", 11, UI.C_MUTED, true)
	note.custom_minimum_size = Vector2(380.0, 0.0)
	col.add_child(note)


func _num(x: float) -> String:
	if absf(x - roundf(x)) < 0.005:
		return str(int(roundf(x)))
	return "%.2f" % x


func _range(d: Dictionary, _scale: float, _unit: String) -> String:
	var text: String = "%s to %s" % [_num(float(d.get("min", 0.0))), _num(float(d.get("max", 0.0)))]
	if d.has("typical"):
		text += " (typically %s)" % _num(float(d["typical"]))
	return text


func _rate(kbps: float) -> String:
	if kbps >= 1000.0:
		return "%s Mbps" % _num(kbps / 1000.0)
	return "%s kbps" % _num(kbps)


func _on_craft(id: String) -> void:
	if id != GameState.craft_id:
		GameState.set_craft(id)
		GameState.go("briefing")  # rebuild this screen for the new size


func _chip(chip: Dictionary) -> Button:
	var chosen: bool = str(chip.get("state", "")) == "chosen"
	var label: String = str(chip.get("label", ""))
	var b: Button = UI.button(label, Callable(), 10.0, false)
	b.custom_minimum_size = Vector2(0.0, 40.0)
	if chosen:
		b.add_theme_stylebox_override("normal", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 2, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 2, 8.0))
	else:
		b.text = label + " (locked)"
		b.add_theme_stylebox_override("normal", UI.box(UI.C_DISABLED, UI.C_DISABLED_BORDER, 16, 2, 8.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.C_DISABLED, UI.C_DISABLED_BORDER, 16, 2, 8.0))
		b.add_theme_color_override("font_color", UI.C_MUTED)
		b.add_theme_color_override("font_hover_color", UI.C_MUTED)
		b.pressed.connect(_on_locked_chip.bind(label, str(chip.get("why", ""))))
	return b


func _build_requirements() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(872, 88), Vector2(388, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("You must hit", 20))
	var list: Array = GameState.level.get("requirements", [])
	for item in list:
		var r: Dictionary = item
		var text: Label = UI.label("%s  %s" % [str(r.get("id", "")), str(r.get("text", ""))], 14, UI.C_TEXT, true)
		text.custom_minimum_size = Vector2(350.0, 0.0)
		col.add_child(text)
	# the rocket this mission rides, and why it is the right one
	var rocket: Dictionary = GameState.level.get("rocket", {})
	if not rocket.is_empty():
		col.add_child(UI.label("Your ride: " + str(rocket.get("name", "")), 14, UI.C_ACCENT))
		var row: HBoxContainer = UI.hbox(10)
		col.add_child(row)
		row.add_child(UI.picture("res://art/modules/%s.png" % str(rocket.get("kind", "")), Vector2(54, 150), "rocket"))
		var why: Label = UI.label(str(rocket.get("why", "")), 13, UI.C_TEXT, true)
		why.custom_minimum_size = Vector2(286.0, 0.0)
		row.add_child(why)


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	var any_locked: bool = false
	for item in GameState.level.get("concept_chips", []):
		if str((item as Dictionary).get("state", "")) == "locked":
			any_locked = true
	_tip = UI.label("Click a locked choice to see why it is locked." if any_locked else "Read the goal and the limits, then press Start building.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 590), Vector2(160, 52))
	_place(UI.button("Start building", _on_start, 260.0, true), Vector2(1000, 590), Vector2(260, 52))


func _on_locked_chip(label: String, why: String) -> void:
	_tip.text = "%s is locked: %s" % [label, why]


func _on_start() -> void:
	GameState.go("workshop")  # do not reset here: Retry must keep the parts


func _on_back() -> void:
	GameState.go("missions")
