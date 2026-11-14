extends Control
## How to play: the whole game on one screen, as pictures with one short line each.
## Opened from the title screen and the menu.

const UI = preload("res://scripts/ui/ui.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")

## [title, colour, one short line, picture (a sprite name)]
const STEPS: Array = [
	["Train", Color(0.62, 0.55, 0.96), "4 quick puzzles", "part_battery"],
	["Brief", Color(0.36, 0.86, 0.95), "Read the goal and limits", "earth_large"],
	["Build", Color(0.36, 0.76, 0.48), "Fit parts, turn the bars green", "cubesat_3u"],
	["Test", Color(0.95, 0.79, 0.30), "Fix problems or take the risk", "part_antenna_large"],
	["Launch", Color(0.95, 0.55, 0.16), "Too heavy or flawed? It fails", "rocket_medium"],
	["Fly", Color(0.45, 0.75, 0.98), "Run it week by week", "ground_station"],
	["Report", Color(0.97, 0.55, 0.68), "Up to 3 stars, and why", "icon_health"],
]

## The four rules worth remembering, each with a small drawn icon: [icon, words].
const RULES: Array = [
	["clock", "Every day costs money"],
	["wrench", "Removing a part costs rework time"],
	["timer", "Events have a timer: answer or pay a penalty"],
	["star", "20 missions, each from a real spaceflight"],
]


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _ready() -> void:
	add_child(Chrome.top_bar("How to play", []))
	add_child(Chrome.tip_bar("Open the menu on the left edge any time for sound, text size and sources."))
	# the mission flow as a row of picture cards joined by arrows
	var x: float = 20.0
	var w: float = 166.0
	for i in range(STEPS.size()):
		var step: Array = STEPS[i]
		var card: PanelContainer = UI.panel(step[1], 10.0)
		_place(card, Vector2(x, 96), Vector2(w, 270))
		var col: VBoxContainer = UI.vbox(6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(col)
		var head: HBoxContainer = UI.hbox(8)
		col.add_child(head)
		head.add_child(UI.label("%d" % (i + 1), 26, step[1]))
		head.add_child(UI.label(str(step[0]), 20, UI.C_TEXT))
		var pic: Control = UI.picture("res://art/modules/%s.png" % str(step[3]), Vector2(w - 30.0, 130.0), str(step[0]))
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(pic)
		var line: Label = UI.label(str(step[2]), 14, UI.C_TEXT, true)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.custom_minimum_size = Vector2(w - 22.0, 0.0)
		col.add_child(line)
		if i < STEPS.size() - 1:
			var arrow: Label = UI.label(">", 26, UI.C_ACCENT)
			_place(arrow, Vector2(x + w - 2.0, 210), Vector2(16, 40))
		x += w + 12.0
	# the rules as four icon tiles
	var rx: float = 20.0
	for item in RULES:
		var rule: Array = item
		var tile: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
		_place(tile, Vector2(rx, 384), Vector2(298, 196))
		var tcol: VBoxContainer = UI.vbox(10)
		tcol.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(tcol)
		var icon: Control = Control.new()
		icon.custom_minimum_size = Vector2(90, 90)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.draw.connect(_draw_icon.bind(icon, str(rule[0])))
		tcol.add_child(icon)
		var words: Label = UI.label(str(rule[1]), 16, UI.C_TEXT, true)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.custom_minimum_size = Vector2(270.0, 0.0)
		tcol.add_child(words)
		rx += 312.0
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 600), Vector2(160, 52))
	_place(UI.button("Play", _on_play, 220.0, true), Vector2(1040, 600), Vector2(220, 52))


func _draw_icon(c: Control, kind: String) -> void:
	var m: Vector2 = c.size * 0.5
	var col: Color = UI.C_ACCENT
	match kind:
		"clock":
			c.draw_arc(m, 36.0, 0.0, TAU, 48, col, 4.0)
			c.draw_line(m, m + Vector2(0, -24), col, 4.0)
			c.draw_line(m, m + Vector2(18, 8), col, 4.0)
			c.draw_string(UI.display_font(), m + Vector2(22, 40), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.C_GOLD)
		"wrench":
			c.draw_line(m + Vector2(-26, 26), m + Vector2(14, -14), col, 10.0)
			c.draw_arc(m + Vector2(20, -20), 16.0, PI * 0.9, PI * 2.6, 24, col, 8.0)
		"timer":
			c.draw_arc(m + Vector2(0, 6), 32.0, 0.0, TAU, 48, col, 4.0)
			c.draw_arc(m + Vector2(0, 6), 32.0, -PI * 0.5, PI * 0.9, 48, UI.C_RED, 6.0)
			c.draw_rect(Rect2(m + Vector2(-8, -36), Vector2(16, 6)), col)
		"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var r: float = 36.0 if i % 2 == 0 else 15.0
				var a: float = -PI * 0.5 + PI * float(i) / 5.0
				pts.append(m + Vector2(cos(a), sin(a)) * r)
			c.draw_colored_polygon(pts, UI.C_GOLD)


func _on_back() -> void:
	GameState.go("title")


func _on_play() -> void:
	GameState.profile_next = "ladder"
	GameState.go("ladder" if GameState.has_profile() else "profile")
