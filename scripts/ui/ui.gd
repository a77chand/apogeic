extends RefCounted
## Small helpers so every screen looks the same and survives missing art.
## Use it through a preload:  const UI = preload("res://scripts/ui/ui.gd")
## Everything here builds plain Godot Control nodes in code.

const Sprites = preload("res://scripts/ui/sprites.gd")
const Starfield = preload("res://scripts/ui/starfield.gd")

const C_BG: Color = Color(0.043, 0.114, 0.227)  # 0B1D3A
const C_PANEL: Color = Color(0.122, 0.227, 0.373)  # 1F3A5F
const C_DEEP: Color = Color(0.078, 0.157, 0.290)  # 14284A
const C_OUTLINE: Color = Color(0.027, 0.067, 0.122)  # 07111F
const C_TEXT: Color = Color(0.949, 0.961, 0.980)  # F2F5FA
const C_MUTED: Color = Color(0.780, 0.815, 0.870)  # brighter than A8B2C1 so it reads on dark panels
## Style: a restrained mission-control look. Dark steel-blue surfaces, thin cyan edges,
## angled (chamfered) corners, uppercase technical headings. Gold is kept for stars only.
const C_GOLD: Color = Color(0.98, 0.80, 0.33)
const C_ACCENT: Color = Color(0.36, 0.86, 0.95)           # the cyan used for edges and highlights
const C_BTN_MAIN: Color = Color(0.20, 0.62, 0.74)         # main action: a solid teal
const C_BTN: Color = Color(0.07, 0.13, 0.24)              # other buttons: dark, with a cyan edge
const C_TEXT_EDGE: Color = Color(0.01, 0.03, 0.08, 0.85)  # thin outline around all text
const FONT_PATH: String = "res://art/fonts/Rajdhani-Bold.ttf"
const PIXEL_FONT: String = "res://art/fonts/Silkscreen-Regular.ttf"
const PIXEL_FONT_BOLD: String = "res://art/fonts/Silkscreen-Bold.ttf"
const TITLE_SIZE: int = 26     # labels this size or bigger are titles, in the pixel font
const HEADING_SIZE: int = 18   # labels this size or bigger use the display font, in capitals
const C_BORDER: Color = Color(0.310, 0.525, 0.839)  # 4F86D6
const C_HOVER: Color = Color(0.169, 0.365, 0.659)  # 2B5DA8
const C_CYAN: Color = Color(0.247, 0.816, 0.878)  # 3FD0E0
const C_GREEN: Color = Color(0.247, 0.725, 0.314)  # 3FB950
const C_YELLOW: Color = Color(0.949, 0.788, 0.298)  # F2C94C
const C_RED: Color = Color(0.898, 0.282, 0.302)  # E5484D
const C_ORANGE: Color = Color(0.949, 0.549, 0.157)  # F28C28
const C_DISABLED: Color = Color(0.227, 0.263, 0.322)  # 3A4352
const C_DISABLED_BORDER: Color = Color(0.357, 0.396, 0.467)  # 5B6577


## The display font (Rajdhani Bold, OFL) with a little extra space between letters.
## Falls back to Godot's font if the file is missing.
static func display_font() -> Font:
	if not ResourceLoader.exists(FONT_PATH):
		return ThemeDB.fallback_font
	var f: FontVariation = FontVariation.new()
	f.base_font = load(FONT_PATH)
	f.spacing_glyph = 1
	return f


## The pixel font used for the title and the main menu (Silkscreen, OFL).
static func pixel_font(bold: bool = true) -> Font:
	var path: String = PIXEL_FONT_BOLD if bold else PIXEL_FONT
	if not ResourceLoader.exists(path):
		return display_font()
	return load(path)


## A menu button in the title-screen style: near-black, thin rounded light edge, pixel text.
## main = the big choices (Play, Skip); accent = the colour of the edge and text.
static func pixel_button(text: String, on_press: Callable, width: float, height: float, font_size: int, accent: Color) -> Button:
	var b: Button = Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(width, height)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", pixel_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.05, 0.12))
	b.add_theme_color_override("font_pressed_color", Color(0.06, 0.05, 0.12))
	var normal: StyleBoxFlat = box(Color(0.02, 0.02, 0.06, 0.88), Color(accent, 0.85), 8, 2, 8.0)
	var hover: StyleBoxFlat = box(accent, accent, 8, 2, 8.0)
	var pressed: StyleBoxFlat = box(accent.darkened(0.2), accent, 8, 2, 8.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_click_sound)
	b.pressed.connect(on_press)
	return b


## "Based on mission ___" for a level based on a real spaceflight, as a small gold tag.
## Returns an empty Control when the level has no based_on block.
static func based_on_tag(level: Dictionary, width: float = 360.0) -> Control:
	var b: Dictionary = level.get("based_on", {})
	if b.is_empty():
		return Control.new()
	var tag: PanelContainer = PanelContainer.new()
	tag.add_theme_stylebox_override("panel", box(Color(C_GOLD, 0.12), Color(C_GOLD, 0.8), 4, 1, 6.0))
	var l: Label = label("Based on mission %s  ·  %s, %d" % [str(b.get("mission", "")), str(b.get("country", "")), int(b.get("year", 0))], 12, C_GOLD, true)
	l.custom_minimum_size = Vector2(width - 14.0, 0.0)
	tag.add_child(l)
	tag.tooltip_text = "%s\nSource: %s" % [str(b.get("story", "")), str(b.get("source", ""))]
	return tag


## A star drawn in code: gold when earned, a dim outline when not.
static func star_icon(lit: bool, size: float = 22.0) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		var m: Vector2 = Vector2(size, size) * 0.5
		for i in range(10):
			var r: float = size * (0.5 if i % 2 == 0 else 0.21)
			var a: float = -PI * 0.5 + PI * float(i) / 5.0
			pts.append(m + Vector2(cos(a), sin(a)) * r)
		if lit:
			c.draw_colored_polygon(pts, C_GOLD)
		else:
			pts.append(pts[0])
			c.draw_polyline(pts, Color(C_MUTED, 0.45), 1.5, true))
	return c


static func star_row(count: int, size: float = 24.0) -> HBoxContainer:
	var row: HBoxContainer = hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		row.add_child(star_icon(i < count, size))
	return row


## A pixel heart for the lives display: red when full, a dim outline when used.
const HEART_PIXELS: Array = [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]


static func heart_icon(full: bool, size: float = 20.0) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var px: float = floorf(size / 7.0)
		var off: Vector2 = Vector2((size - px * 7.0) * 0.5, (size - px * 6.0) * 0.5)
		for y in range(HEART_PIXELS.size()):
			var row: String = HEART_PIXELS[y]
			for x in range(row.length()):
				if row[x] != "X":
					continue
				var r: Rect2 = Rect2(off + Vector2(x, y) * px, Vector2(px, px))
				if full:
					c.draw_rect(r, C_RED if not (y == 1 and x == 1) else Color(1, 0.75, 0.75))
				else:
					c.draw_rect(r, Color(C_MUTED, 0.22)))
	return c


## A small icon drawn at the left of a button (the text stays centred). Kinds: sparkle,
## target, speaker, note, bulb, reset, book, rocket.
static func add_icon(b: Button, kind: String, color: Color, size: float = 18.0) -> void:
	# make room on the left so the text never runs under the icon
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(state)
		if sb != null:
			var copy: StyleBox = sb.duplicate()
			copy.content_margin_left = size * 1.8 + 8.0
			copy.content_margin_right = maxf(copy.content_margin_right, 8.0)
			b.add_theme_stylebox_override(state, copy)
	b.draw.connect(func() -> void:
		var m: Vector2 = Vector2(size * 0.9 + 6.0, b.size.y * 0.5)
		draw_icon(b, kind, m, size, color))


static func draw_icon(ci: CanvasItem, kind: String, m: Vector2, s: float, color: Color) -> void:
	var w: float = maxf(1.5, s * 0.11)
	match kind:
		"sparkle":
			_draw_sparkle(ci, m, s * 0.62, Color(1.0, 0.85, 0.35, 0.3))
			_draw_sparkle(ci, m, s * 0.52, Color(1.0, 0.82, 0.30))
			_draw_sparkle(ci, m, s * 0.18, Color(1, 1, 0.9))
		"target":
			var gold: Color = Color(0.98, 0.78, 0.30)
			ci.draw_arc(m, s * 0.42, 0.0, TAU, 32, gold, w)
			ci.draw_arc(m, s * 0.20, 0.0, TAU, 24, gold, w)
			ci.draw_circle(m, s * 0.07, gold)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(m + d * s * 0.30, m + d * s * 0.58, gold, w)
		"speaker":
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.45, -s * 0.15), m + Vector2(-s * 0.25, -s * 0.15), m + Vector2(0, -s * 0.38), m + Vector2(0, s * 0.38), m + Vector2(-s * 0.25, s * 0.15), m + Vector2(-s * 0.45, s * 0.15)]), color)
			ci.draw_arc(m + Vector2(s * 0.05, 0), s * 0.22, -0.9, 0.9, 12, color, w)
			ci.draw_arc(m + Vector2(s * 0.05, 0), s * 0.40, -0.9, 0.9, 12, color, w)
		"note":
			ci.draw_circle(m + Vector2(-s * 0.18, s * 0.26), s * 0.14, color)
			ci.draw_circle(m + Vector2(s * 0.26, s * 0.18), s * 0.14, color)
			ci.draw_line(m + Vector2(-s * 0.05, s * 0.26), m + Vector2(-s * 0.05, -s * 0.36), color, w)
			ci.draw_line(m + Vector2(s * 0.39, s * 0.18), m + Vector2(s * 0.39, -s * 0.44), color, w)
			ci.draw_line(m + Vector2(-s * 0.05, -s * 0.36), m + Vector2(s * 0.39, -s * 0.44), color, w * 1.6)
		"bulb":
			ci.draw_circle(m + Vector2(0, -s * 0.08), s * 0.26, Color(1.0, 0.86, 0.35))
			ci.draw_rect(Rect2(m + Vector2(-s * 0.12, s * 0.16), Vector2(s * 0.24, s * 0.2)), color)
		"reset":
			ci.draw_arc(m, s * 0.32, 0.4, TAU - 0.3, 24, color, w)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.32, -s * 0.22), m + Vector2(s * 0.48, s * 0.06), m + Vector2(s * 0.14, s * 0.04)]), color)
		"book":
			ci.draw_rect(Rect2(m + Vector2(-s * 0.46, -s * 0.30), Vector2(s * 0.42, s * 0.6)), color, false, w)
			ci.draw_rect(Rect2(m + Vector2(s * 0.04, -s * 0.30), Vector2(s * 0.42, s * 0.6)), color, false, w)
			for i in range(3):
				var y: float = -s * 0.14 + float(i) * s * 0.14
				ci.draw_line(m + Vector2(-s * 0.38, y), m + Vector2(-s * 0.12, y), color, 1.0)
				ci.draw_line(m + Vector2(s * 0.12, y), m + Vector2(s * 0.38, y), color, 1.0)
		"rocket":
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -s * 0.5), m + Vector2(s * 0.16, -s * 0.2), m + Vector2(s * 0.16, s * 0.25), m + Vector2(-s * 0.16, s * 0.25), m + Vector2(-s * 0.16, -s * 0.2)]), Color(0.92, 0.94, 0.98))
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.16, 0), m + Vector2(-s * 0.36, s * 0.32), m + Vector2(-s * 0.16, s * 0.22)]), color)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.16, 0), m + Vector2(s * 0.36, s * 0.32), m + Vector2(s * 0.16, s * 0.22)]), color)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.1, s * 0.27), m + Vector2(0, s * 0.52), m + Vector2(s * 0.1, s * 0.27)]), Color(1.0, 0.62, 0.2))


## The star dust sparkle: a four-pointed star with a small one beside it (from the
## reference sheet of sparkles), in pale violet.
static func sparkle_icon(size: float = 22.0, color: Color = Color(0.80, 0.72, 1.0)) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		_draw_sparkle(c, Vector2(size * 0.42, size * 0.58), size * 0.40, Color(color, 0.25))
		_draw_sparkle(c, Vector2(size * 0.42, size * 0.58), size * 0.34, color)
		_draw_sparkle(c, Vector2(size * 0.42, size * 0.58), size * 0.12, Color(1, 1, 1))
		_draw_sparkle(c, Vector2(size * 0.85, size * 0.17), size * 0.14, color))
	return c


## A sparkle drawn on another control (used for pictures in cards).
static func draw_sparkle_at(ci: CanvasItem, m: Vector2, r: float, color: Color) -> void:
	_draw_sparkle(ci, m, r, Color(color, 0.25))
	_draw_sparkle(ci, m, r * 0.85, color)
	_draw_sparkle(ci, m, r * 0.3, Color(1, 1, 1))


## A four-pointed sparkle with curved sides: long points up, down, left and right.
static func _draw_sparkle(ci: CanvasItem, m: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 8
	for q in range(4):
		var a0: float = -PI * 0.5 + PI * 0.5 * float(q)
		var a1: float = a0 + PI * 0.5
		var tip0: Vector2 = m + Vector2(cos(a0), sin(a0)) * r
		var tip1: Vector2 = m + Vector2(cos(a1), sin(a1)) * r
		for i in range(steps):
			var t: float = float(i) / float(steps)
			# a curve that bows in towards the centre between two points
			var p: Vector2 = tip0.lerp(tip1, t)
			pts.append(p.lerp(m, sin(t * PI) * 0.52))
	ci.draw_colored_polygon(pts, color)


## A short message in the bottom-right corner that fades out after a few seconds.
## Used for feedback after a choice: how good it was and why.
static func toast(host: Node, title: String, text: String, color: Color, seconds: float = 6.0) -> void:
	var panel: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = box(Color(0.02, 0.05, 0.11, 0.95), color, 8, 2, 12.0)
	sb.border_width_left = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 50
	var col: VBoxContainer = vbox(4)
	panel.add_child(col)
	col.add_child(label(title, 18, color))
	var l: Label = label(text, 14, C_TEXT, true)
	l.custom_minimum_size = Vector2(380.0, 0.0)
	col.add_child(l)
	host.add_child(panel)
	panel.position = Vector2(1270.0, 470.0)
	panel.size = Vector2(410.0, 0.0)
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "position:x", 850.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(panel, "modulate:a", 0.0, 0.8)
	tw.tween_callback(panel.queue_free)


## The feedback toast for an event choice (see Sim.choice_rating).
static func choice_toast(host: Node, rating: Dictionary, late: bool) -> void:
	var r: String = str(rating.get("rating", "fair"))
	var why: String = str(rating.get("why", ""))
	var real: String = str(rating.get("real", ""))
	if real != "":
		# this is the choice the real team made: say so, and leave it up longer to read
		why += "\nReal life: " + real
	var secs: float = 12.0 if real != "" else 6.0
	if late:
		toast(host, "Time ran out", "The default was picked for you. " + why, C_RED, secs)
	elif r == "best":
		toast(host, "Optimal choice. Well done!", why, C_GREEN, secs)
	elif r == "fair":
		toast(host, "Fair choice", why, C_YELLOW, secs)
	else:
		toast(host, "Costly choice", why, C_RED, secs)


static func label(text: String, size: int = 16, color: Color = C_TEXT, wrap: bool = false) -> Label:
	# The menu's text size setting: every label below title size follows it (small 0.9,
	# medium 1, large 1.2), so puzzles, missions and pop-ups all change together. Titles
	# keep their size because they sit in fixed bars.
	var asked: int = size   # the font style follows the size asked for, not the scaled size
	if size < TITLE_SIZE:
		size = maxi(9, int(round(float(size) * _font_scale())))
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# A dark outline on every label, so text never blends into the background behind it.
	l.add_theme_color_override("font_outline_color", C_TEXT_EDGE)
	l.add_theme_constant_override("outline_size", clampi(size / 8, 2, 4))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	if asked >= TITLE_SIZE:
		# screen titles and big headings: the same pixel font as the game's title, everywhere
		l.add_theme_font_override("font", pixel_font(false))
		l.add_theme_font_size_override("font_size", size - 4)   # the pixel font runs wide
		l.uppercase = true
	elif asked >= HEADING_SIZE:
		l.add_theme_font_override("font", display_font())
		l.add_theme_font_size_override("font_size", size + 4)   # the display font runs small
		l.uppercase = true
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func box(fill: Color, border: Color, radius: int = 16, border_width: int = 2, margin: float = 12.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A slim mission-control button: dark fill, thin cyan edge, angled corners. The main action is solid teal. Hover lights the edge with a soft glow; pressing
## dims it and nudges the text down slightly. on_press may be an empty Callable.
static func button(text: String, on_press: Callable, min_width: float = 220.0, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 52.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", int(round(18.0 * _font_scale())))
	var fill: Color = C_BTN_MAIN if primary else C_BTN
	var edge: Color = C_ACCENT if not primary else Color(0.62, 0.95, 1.0)
	b.add_theme_stylebox_override("normal", chunky(fill, Color(edge, 0.75), false))
	b.add_theme_stylebox_override("hover", _glow(chunky(fill.lightened(0.10), edge, false)))
	b.add_theme_stylebox_override("pressed", chunky(fill.darkened(0.15), edge, true))
	b.add_theme_stylebox_override("hover_pressed", chunky(fill.darkened(0.15), edge, true))
	b.add_theme_stylebox_override("disabled", chunky(Color(0.10, 0.12, 0.16), Color(0.30, 0.34, 0.42), false))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.85, 0.92, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.49, 0.56))
	b.add_theme_color_override("font_outline_color", C_TEXT_EDGE)
	b.add_theme_constant_override("outline_size", 2)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b.pressed.connect(_click_sound)
	return b


## The button shape: angled corners (corner_detail 1 turns a rounded corner into a straight
## cut). pressed = text nudged down 2 px. Kept the name "chunky" so existing calls still work.
static func chunky(fill: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.border_width_left = 3              # a thicker left edge, like a HUD tab
	sb.set_corner_radius_all(9)
	sb.corner_detail = 1
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 11.0 if pressed else 9.0
	sb.content_margin_bottom = 9.0 if pressed else 11.0
	return sb


static func _glow(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.shadow_color = Color(C_ACCENT, 0.30)
	sb.shadow_size = 8
	return sb


## Static code cannot use the GameState autoload by name, so find it through the tree.
static func _click_sound() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var state: Node = tree.root.get_node_or_null("GameState")
	if state != null:
		state.call("play_sound", "click")


## A font size scaled by the menu's text size (use for fonts set by hand on buttons).
static func fs(size: int) -> int:
	return maxi(9, int(round(float(size) * _font_scale())))


static func _font_scale() -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var state: Node = tree.root.get_node_or_null("GameState")
	if state == null:
		return 1.0
	return float(state.call("font_scale"))


## A list of short lines, each with a bullet in front. Use instead of a long paragraph.
## width is the wrapping width of each line.
static func bullets(lines: Array, size: int = 15, color: Color = C_TEXT, width: float = 260.0, mark_color: Color = C_ACCENT) -> VBoxContainer:
	var col: VBoxContainer = vbox(6)
	for item in lines:
		var row: HBoxContainer = hbox(8)
		var mark: Label = label("•", size, mark_color)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var text: Label = label(str(item), size, color, true)
		text.custom_minimum_size = Vector2(width - 20.0, 0.0)
		row.add_child(text)
		col.add_child(row)
	return col


## Makes a button look locked (grey) while still letting it be clicked, e.g. to explain why.
static func look_locked(b: Button) -> void:
	var fill: Color = Color(0.09, 0.11, 0.15)
	var edge: Color = Color(0.32, 0.36, 0.44)
	b.add_theme_stylebox_override("normal", chunky(fill, edge, false))
	b.add_theme_stylebox_override("hover", chunky(fill.lightened(0.06), edge, false))
	b.add_theme_stylebox_override("pressed", chunky(fill, edge, true))
	b.add_theme_color_override("font_color", Color(0.52, 0.56, 0.64))
	b.add_theme_color_override("font_hover_color", Color(0.62, 0.66, 0.74))


## A panel: deep steel-blue, a thin cyan edge, angled corners, a soft shadow, and short
## cyan tick marks in the corners like a HUD frame (main panels only).
static func panel(border: Color = C_BORDER, margin: float = 16.0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = box(Color(0.04, 0.09, 0.18, 0.86), Color(border, 0.55), 12, 1, margin)   # glassy: stars show faintly
	sb.corner_detail = 1
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", sb)
	if margin >= 12.0:
		p.draw.connect(_brackets.bind(p))
	return p


## A sci-fi panel: cut corners, a soft neon edge, a few circuit-style details (a tab on
## the top edge, three slashes, small nodes on the side lines). The fill is dark and nearly
## solid so text on it stays easy to read.
static func neon_panel(color: Color = C_CYAN, margin: float = 18.0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxEmpty = StyleBoxEmpty.new()
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin + 6.0
	sb.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", sb)
	p.draw.connect(_neon.bind(p, color))
	return p


static func _neon(p: Control, color: Color) -> void:
	var s: Vector2 = p.size
	var cut: float = 18.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(cut, 0), Vector2(s.x * 0.55, 0), Vector2(s.x * 0.55 + 10.0, 6.0), Vector2(s.x - cut, 6.0), Vector2(s.x, 6.0 + cut),
		Vector2(s.x, s.y - cut), Vector2(s.x - cut, s.y), Vector2(cut + 30.0, s.y), Vector2(cut + 22.0, s.y - 6.0), Vector2(cut, s.y - 6.0),
		Vector2(0, s.y - 6.0 - cut), Vector2(0, cut)])
	p.draw_colored_polygon(pts, Color(0.02, 0.05, 0.11, 0.94))
	var outline: PackedVector2Array = pts.duplicate()
	outline.append(pts[0])
	for i in range(3):
		p.draw_polyline(outline, Color(color, 0.08), 8.0 - float(i) * 2.5, true)
	p.draw_polyline(outline, Color(color, 0.9), 1.6, true)
	# a tab on the top edge and three slashes at the top right
	p.draw_rect(Rect2(cut + 10.0, -3.0, 70.0, 4.0), Color(color, 0.95))
	for i in range(3):
		var x: float = s.x - cut - 60.0 + float(i) * 12.0
		p.draw_line(Vector2(x, 14.0), Vector2(x + 8.0, 10.0), Color(color, 0.8), 3.0)
	# small circuit nodes on the left and right edges
	for y in [s.y * 0.30, s.y * 0.34]:
		p.draw_line(Vector2(-10.0, y), Vector2(0, y), Color(color, 0.6), 1.5)
		p.draw_circle(Vector2(-12.0, y), 2.5, Color(color, 0.8))
	p.draw_line(Vector2(s.x, s.y * 0.7), Vector2(s.x + 10.0, s.y * 0.7), Color(color, 0.6), 1.5)
	p.draw_circle(Vector2(s.x + 12.0, s.y * 0.7), 2.5, Color(color, 0.8))


## Short cyan ticks at the four corners of a panel (drawn under its contents).
static func _brackets(p: Control) -> void:
	var s: Vector2 = p.size
	var arm: float = minf(16.0, minf(s.x, s.y) * 0.15)
	var inset: float = 5.0
	var c: Color = Color(C_ACCENT, 0.75)
	p.draw_line(Vector2(arm + 10.0, 1.5), Vector2(s.x - arm - 10.0, 1.5), Color(C_ACCENT, 0.18), 1.0)   # glass highlight
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var x: float = inset if corner.x == 0 else s.x - inset
		var y: float = inset if corner.y == 0 else s.y - inset
		var dx: float = arm if corner.x == 0 else -arm
		var dy: float = arm if corner.y == 0 else -arm
		p.draw_line(Vector2(x, y), Vector2(x + dx, y), c, 2.0)
		p.draw_line(Vector2(x, y), Vector2(x, y + dy), c, 2.0)


## The strip along the top (top = true) or bottom of a screen: dark and see-through, so the
## stars show behind it, with a glowing cyan line on the edge that faces the screen.
static func bar_style(top: bool = true) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.12, 0.72)
	sb.border_color = Color(C_ACCENT, 0.65)
	sb.border_width_bottom = 2 if top else 0
	sb.border_width_top = 0 if top else 2
	sb.shadow_color = Color(C_ACCENT, 0.12)
	sb.shadow_size = 10
	sb.set_content_margin_all(12.0)
	return sb


## A dark vignette over the background, so the edges fall into shadow and the middle glows.
## It is a tiny shader built in code, which the web (Compatibility) renderer supports.
static func vignette() -> Control:
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 d = (UV - vec2(0.5)) * vec2(1.0, 0.85);\n\tCOLOR = vec4(0.0, 0.0, 0.03, smoothstep(0.38, 0.80, length(d)) * 0.65);\n}\n"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


static func vbox(separation: int = 10) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 10) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


## A full-screen dark background. Add it first so it sits behind everything.
static func background(path: String = "res://art/backgrounds/bg_space.png") -> Control:
	if ResourceLoader.exists(path):
		var t: TextureRect = TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return t
	var stars: Control = Starfield.new()   # no art yet: draw a starry sky in code
	stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return stars


## A meter bar. Call set_meter() to update it.
static func meter(width: float = 260.0) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 16.0)
	bar.add_theme_stylebox_override("background", box(C_OUTLINE, C_OUTLINE, 8, 0, 0.0))
	bar.add_theme_stylebox_override("fill", box(C_GREEN, C_GREEN, 8, 0, 0.0))
	return bar


## percent is clamped to 0..100. status is "green", "yellow" or "red".
static func set_meter(bar: ProgressBar, percent: float, status: String) -> void:
	bar.value = clampf(percent, 0.0, 100.0)
	var color: Color = C_GREEN
	if status == "yellow":
		color = C_YELLOW
	elif status == "red":
		color = C_RED
	bar.add_theme_stylebox_override("fill", box(color, color, 8, 0, 0.0))


const BANNER_OK: String = "res://art/ui/mission_completed.png"
const BANNER_FAIL: String = "res://art/ui/mission_failed.png"


## The team's MISSION COMPLETED / MISSION FAILED drawing, sized to `width` (null if missing).
static func result_art(ok: bool, width: float) -> Control:
	var path: String = BANNER_OK if ok else BANNER_FAIL
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var t: TextureRect = TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(width, width * float(tex.get_height()) / float(tex.get_width()))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Pops the MISSION COMPLETED / FAILED drawing over the middle of the screen for a moment.
static func result_banner(host: Node, ok: bool, seconds: float = 1.6) -> void:
	var art: Control = result_art(ok, 900.0)
	if art == null:
		return
	var strip: ColorRect = ColorRect.new()
	strip.color = Color(0, 0, 0, 0.7)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.z_index = 90
	host.add_child(strip)
	strip.position = Vector2(0, 300)
	strip.size = Vector2(1280, 120)
	strip.add_child(art)
	art.size = art.custom_minimum_size
	art.position = Vector2((1280.0 - art.size.x) * 0.5, (120.0 - art.size.y) * 0.5)
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2(1.3, 1.3)
	var tw: Tween = strip.create_tween()
	tw.tween_property(art, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_property(strip, "modulate:a", 0.0, 0.3)
	tw.tween_callback(strip.queue_free)


## Shows the picture at path. If the file is not there yet, shows a labelled box
## of the same size, so missing art never breaks a screen.
static func picture(path: String, size: Vector2, fallback_text: String = "") -> Control:
	if path != "" and ResourceLoader.exists(path):
		var t: TextureRect = TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = size
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var key: String = path.get_file().get_basename()
	if Sprites.KINDS.has(key):
		return Sprites.make(key, size)   # a drawing stands in until the artist's PNG arrives
	var holder: PanelContainer = PanelContainer.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_theme_stylebox_override("panel", box(C_DEEP, C_DISABLED_BORDER, 8, 2, 4.0))
	var text: String = fallback_text
	if text == "":
		text = path.get_file()
	var l: Label = label(text, 11, C_MUTED, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(l)
	return holder


## Builds an animation from numbered frames: folder/base_01.png, base_02.png ...
## Returns null if frame 01 is missing. Never lists a directory, because that
## does not work in an exported game.
static func frames(folder: String, base: String, count: int, fps: float, loop: bool) -> SpriteFrames:
	var first: String = "%s/%s_%02d.png" % [folder, base, 1]
	if not ResourceLoader.exists(first):
		return null
	var sf: SpriteFrames = SpriteFrames.new()
	if not sf.has_animation(base):
		sf.add_animation(base)
	sf.set_animation_speed(base, fps)
	sf.set_animation_loop(base, loop)
	for i in range(1, count + 1):
		var path: String = "%s/%s_%02d.png" % [folder, base, i]
		if ResourceLoader.exists(path):
			sf.add_frame(base, load(path))
	return sf


## 880.0 -> "$880k", 1000.0 -> "$1.00M", -20.0 -> "-$20k"
static func money(k: float) -> String:
	var sign_text: String = ""
	if k < 0.0:
		sign_text = "-"
	var a: float = absf(k)
	if a >= 1000.0:
		return "%s$%.2fM" % [sign_text, a / 1000.0]
	return "%s$%dk" % [sign_text, int(round(a))]


## "green" when comfortably inside the target, "yellow" when close, "red" when failing.
static func status_for(passed: bool, close: bool) -> String:
	if not passed:
		return "red"
	if close:
		return "yellow"
	return "green"


## Removes and frees every child of a node.
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
