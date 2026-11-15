extends Control
## How to play, as a waterfall flowchart: the seven steps step down the screen like a
## staircase, joined by arrows, each with a picture and two short pointers beside it.
## Two loop arrows show the real flow: fix after testing, and retry after the report.
## The golden rules sit in a column on the right. Opened from the title screen and the menu.

const UI = preload("res://scripts/ui/ui.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")

## [title, colour, picture path, pointer 1, pointer 2]
const STEPS: Array = [
	["Train", Color(0.62, 0.55, 0.96), "res://art/icons/icon_battery.png",
		"4 short puzzles: mass, power, data and time", "Each one teaches a rule the missions use"],
	["Brief", Color(0.36, 0.86, 0.95), "res://art/backgrounds/earth_dark.png",
		"Read the goal, the limits and your rocket", "Pick a CubeSat size: 1U, 3U or 6U"],
	["Build", Color(0.36, 0.76, 0.48), "res://art/modules/cubesat_3u.png",
		"Click or drag parts onto the satellite", "Turn the six checks green before the deadline"],
	["Test", Color(0.95, 0.79, 0.30), "res://art/modules/part_antenna_large.png",
		"Tests find hidden flaws before launch", "Fix them (costs days) or take the risk"],
	["Launch", Color(0.95, 0.55, 0.16), "res://art/animations/rocket/rocket_19.png",
		"Too heavy or flawed and it can fail", "You see where it broke, and why"],
	["Fly", Color(0.45, 0.75, 0.98), "res://art/modules/ground_station.png",
		"Run the mission week by week", "Answer events before their timer runs out"],
	["Report", Color(0.97, 0.55, 0.68), "res://art/icons/icon_data.png",
		"Up to 3 stars, with the reasons", "Fix your satellite and fly again"],
]

## The golden rules: [icon, words].
const RULES: Array = [
	["clock", "Every day costs money"],
	["wrench", "Removing a part costs rework time"],
	["timer", "Events have a timer: answer or pay"],
	["star", "20 missions, each from a real spaceflight"],
]

const ROW_H: float = 66.0       # height of one step row
const TOP: float = 92.0         # y of the first step
const CHIP_X: float = 96.0      # x of the first chip
const STAIR: float = 34.0       # each step moves this far right: the waterfall
const CHIP: Vector2 = Vector2(196, 54)

var _lines: Control = null      # draws the arrows and loops


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _chip_rect(i: int) -> Rect2:
	return Rect2(Vector2(CHIP_X + STAIR * float(i), TOP + ROW_H * float(i)), CHIP)


func _ready() -> void:
	add_child(Chrome.top_bar("How to play", []))
	add_child(Chrome.tip_bar("Open the menu on the left edge any time for sound, text size and sources."))
	_lines = Control.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	_place(_lines, Vector2.ZERO, Vector2(1280, 720))
	for i in range(STEPS.size()):
		_build_step(i)
	_build_rules()
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 600), Vector2(160, 52))
	_place(UI.button("Play", _on_play, 220.0, true), Vector2(1040, 600), Vector2(220, 52))


## One step: a coloured chip (number, picture, name) and two pointers to its right.
func _build_step(i: int) -> void:
	var step: Array = STEPS[i]
	var col: Color = step[1]
	var r: Rect2 = _chip_rect(i)
	var chip: PanelContainer = PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(Color(col, 0.16), col, 10, 2, 6.0))
	_place(chip, r.position, r.size)
	var row: HBoxContainer = UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	chip.add_child(row)
	var num: Label = UI.label("%d" % (i + 1), 22, col)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	var pic: Control = UI.picture(str(step[2]), Vector2(52, 38), "")
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var name_label: Label = UI.label(str(step[0]), 18, UI.C_TEXT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	# the pointers: two short lines with an arrow, lined up beside the chip
	var px: float = r.end.x + 30.0
	var pointers: VBoxContainer = UI.vbox(2)
	_place(pointers, Vector2(px, r.position.y + 2.0), Vector2(930.0 - px, r.size.y))
	for k in [3, 4]:
		var line: HBoxContainer = UI.hbox(6)
		pointers.add_child(line)
		line.add_child(UI.label(">", 14, col))
		var words: Label = UI.label(str(step[k]), 14, UI.C_TEXT)
		words.clip_text = true
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)


func _build_rules() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 12.0)
	_place(panel, Vector2(958, 92), Vector2(302, 490))
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label("Golden rules", 20))
	for item in RULES:
		var rule: Array = item
		var row: HBoxContainer = UI.hbox(12)
		col.add_child(row)
		var icon: Control = Control.new()
		icon.custom_minimum_size = Vector2(76, 76)
		icon.draw.connect(_draw_icon.bind(icon, str(rule[0])))
		row.add_child(icon)
		var words: Label = UI.label(str(rule[1]), 15, UI.C_TEXT, true)
		words.custom_minimum_size = Vector2(170.0, 0.0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)


## The waterfall arrows between steps, and the two loops back to Build.
func _draw_lines() -> void:
	var c: Control = _lines
	for i in range(STEPS.size() - 1):
		var a: Rect2 = _chip_rect(i)
		var b: Rect2 = _chip_rect(i + 1)
		# down from under this chip, then right into the next one: an elbow
		var x: float = a.position.x + 18.0
		var start: Vector2 = Vector2(x, a.end.y)
		var bend: Vector2 = Vector2(x, b.position.y + b.size.y * 0.5)
		var end: Vector2 = Vector2(b.position.x - 2.0, bend.y)
		var col: Color = Color((STEPS[i + 1] as Array)[1], 0.9)
		c.draw_line(start, bend, col, 3.0)
		c.draw_line(bend, end, col, 3.0)
		_arrow_head(end, Vector2.RIGHT, col)
	_loop(3, 2, 76.0, 0.5, 40.0, "fix", UI.C_YELLOW)                      # Test -> back to Build
	_loop(6, 2, 46.0, 0.85, 12.0, "retry", Color(0.97, 0.55, 0.68))       # Report -> back to Build


## A dashed loop on the left: out of step `from` (at a share of its height), up the margin
## at x, and into step `to` (enter_y pixels below its top).
func _loop(from: int, to: int, x: float, leave_at: float, enter_y: float, word: String, col: Color) -> void:
	var c: Control = _lines
	var a: Rect2 = _chip_rect(from)
	var b: Rect2 = _chip_rect(to)
	var y0: float = a.position.y + a.size.y * leave_at
	var y1: float = b.position.y + enter_y
	var pts: Array = [Vector2(a.position.x, y0), Vector2(x, y0), Vector2(x, y1), Vector2(b.position.x - 2.0, y1)]
	for k in range(pts.size() - 1):
		c.draw_dashed_line(pts[k], pts[k + 1], col, 2.0, 7.0)
	_arrow_head(pts[3], Vector2.RIGHT, col)
	var font: Font = UI.display_font()
	# the word sits beside the up-line for the short loop, on the bottom line for the long one
	var at: Vector2 = Vector2(x + 5.0, (y0 + y1) * 0.5 + 4.0) if from - to < 3 else Vector2(x + 12.0, y0 - 6.0)
	c.draw_string(font, at, word.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _arrow_head(tip: Vector2, dir: Vector2, col: Color) -> void:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	_lines.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 + side * 6.0, tip - dir * 10.0 - side * 6.0]), col)


func _draw_icon(c: Control, kind: String) -> void:
	var m: Vector2 = c.size * 0.5
	var col: Color = UI.C_ACCENT
	match kind:
		"clock":
			c.draw_arc(m, 30.0, 0.0, TAU, 48, col, 4.0)
			c.draw_line(m, m + Vector2(0, -20), col, 4.0)
			c.draw_line(m, m + Vector2(15, 7), col, 4.0)
			c.draw_string(UI.display_font(), m + Vector2(18, 34), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.C_GOLD)
		"wrench":
			c.draw_line(m + Vector2(-22, 22), m + Vector2(12, -12), col, 9.0)
			c.draw_arc(m + Vector2(17, -17), 13.0, PI * 0.9, PI * 2.6, 24, col, 7.0)
		"timer":
			c.draw_arc(m + Vector2(0, 5), 27.0, 0.0, TAU, 48, col, 4.0)
			c.draw_arc(m + Vector2(0, 5), 27.0, -PI * 0.5, PI * 0.9, 48, UI.C_RED, 6.0)
			c.draw_rect(Rect2(m + Vector2(-7, -30), Vector2(14, 5)), col)
		"star":
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var r: float = 30.0 if i % 2 == 0 else 12.0
				var a: float = -PI * 0.5 + PI * float(i) / 5.0
				pts.append(m + Vector2(cos(a), sin(a)) * r)
			c.draw_colored_polygon(pts, UI.C_GOLD)


func _on_back() -> void:
	GameState.go("title")


func _on_play() -> void:
	GameState.profile_next = "ladder"
	GameState.go("ladder" if GameState.has_profile() else "profile")
