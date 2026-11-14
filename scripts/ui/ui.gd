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


static func label(text: String, size: int = 16, color: Color = C_TEXT, wrap: bool = false) -> Label:
	# The menu's text size setting changes body text only: labels that wrap, so they can
	# reflow. Headings and single-line labels in tight spots (bars, pills) keep their size,
	# and small print on part cards is never made bigger, so cards do not overflow.
	if wrap and size < HEADING_SIZE:
		var scale: float = _font_scale()
		if size > 13 or scale < 1.0:
			size = int(round(float(size) * scale))
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
	if size >= HEADING_SIZE:
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
	b.add_theme_font_size_override("font_size", 18)
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
