extends RefCounted
## Small helpers so every screen looks the same and survives missing art.
## Use it through a preload:  const UI = preload("res://scripts/ui/ui.gd")
## Everything here builds plain Godot Control nodes in code.

const C_BG: Color = Color(0.043, 0.114, 0.227)  # 0B1D3A
const C_PANEL: Color = Color(0.122, 0.227, 0.373)  # 1F3A5F
const C_DEEP: Color = Color(0.078, 0.157, 0.290)  # 14284A
const C_OUTLINE: Color = Color(0.027, 0.067, 0.122)  # 07111F
const C_TEXT: Color = Color(0.949, 0.961, 0.980)  # F2F5FA
const C_MUTED: Color = Color(0.659, 0.698, 0.757)  # A8B2C1
const C_BORDER: Color = Color(0.310, 0.525, 0.839)  # 4F86D6
const C_HOVER: Color = Color(0.169, 0.365, 0.659)  # 2B5DA8
const C_CYAN: Color = Color(0.247, 0.816, 0.878)  # 3FD0E0
const C_GREEN: Color = Color(0.247, 0.725, 0.314)  # 3FB950
const C_YELLOW: Color = Color(0.949, 0.788, 0.298)  # F2C94C
const C_RED: Color = Color(0.898, 0.282, 0.302)  # E5484D
const C_ORANGE: Color = Color(0.949, 0.549, 0.157)  # F28C28
const C_DISABLED: Color = Color(0.227, 0.263, 0.322)  # 3A4352
const C_DISABLED_BORDER: Color = Color(0.357, 0.396, 0.467)  # 5B6577


static func label(text: String, size: int = 16, color: Color = C_TEXT, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
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


## A button drawn with style boxes, so it needs no art. on_press may be an empty Callable.
static func button(text: String, on_press: Callable, min_width: float = 220.0, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 52.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	var fill: Color = C_PANEL
	if primary:
		fill = C_HOVER
	b.add_theme_stylebox_override("normal", box(fill, C_CYAN))
	b.add_theme_stylebox_override("hover", box(C_HOVER.lightened(0.1), C_CYAN))
	b.add_theme_stylebox_override("pressed", box(C_DEEP, C_CYAN))
	b.add_theme_stylebox_override("disabled", box(C_DISABLED, C_DISABLED_BORDER))
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.add_theme_color_override("font_pressed_color", C_TEXT)
	b.add_theme_color_override("font_disabled_color", C_MUTED)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	b.pressed.connect(_click_sound)
	return b


## Static code cannot use the GameState autoload by name, so find it through the tree.
static func _click_sound() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var state: Node = tree.root.get_node_or_null("GameState")
	if state != null:
		state.call("play_sound", "click")


static func panel(border: Color = C_BORDER, margin: float = 16.0) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(C_PANEL, border, 20, 2, margin))
	return p


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
	var c: ColorRect = ColorRect.new()
	c.color = C_BG
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


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
