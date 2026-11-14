extends HBoxContainer
## The game's logo, built in code: a planet with a satellite on a tilted orbit, then the
## name in the display font. Used on the title screen. If art/ui/ui_logo.png is added
## later, title.gd shows that instead.

const UI = preload("res://scripts/ui/ui.gd")

var _emblem: Control = null
var _t: float = 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 22)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem = Control.new()
	_emblem.custom_minimum_size = Vector2(150, 150)
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.draw.connect(_draw_emblem)
	add_child(_emblem)
	var words: VBoxContainer = UI.vbox(-6)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(words)
	var top: Label = UI.label("Space Mission", 54, UI.C_TEXT)
	words.add_child(top)
	var bottom: Label = UI.label("Designer", 54, UI.C_ACCENT)
	words.add_child(bottom)
	var strap: Label = UI.label("NASA Space Apps 2026", 13, UI.C_MUTED)
	strap.add_theme_constant_override("outline_size", 1)
	words.add_child(strap)


func _process(delta: float) -> void:
	_t += delta
	_emblem.queue_redraw()


func _draw_emblem() -> void:
	var c: Vector2 = Vector2(75, 75)
	# soft glow behind the planet
	for i in range(6):
		_emblem.draw_circle(c, 62.0 - float(i) * 3.0, Color(UI.C_ACCENT, 0.03))
	# the planet: blue disc, a lit edge, and two land shapes
	_emblem.draw_circle(c, 44.0, Color(0.10, 0.32, 0.62))
	_emblem.draw_circle(c + Vector2(-6, -6), 38.0, Color(0.16, 0.45, 0.80))
	_emblem.draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -14), c + Vector2(-8, -24), c + Vector2(4, -12), c + Vector2(-6, 2), c + Vector2(-22, 0)]), Color(0.30, 0.70, 0.45))
	_emblem.draw_colored_polygon(PackedVector2Array([c + Vector2(8, 10), c + Vector2(24, 4), c + Vector2(30, 18), c + Vector2(14, 28)]), Color(0.30, 0.70, 0.45))
	_emblem.draw_arc(c, 44.0, PI * 1.05, PI * 1.7, 24, Color(0.75, 0.95, 1.0, 0.8), 2.5)
	# the orbit: a tilted ellipse, the back half faint and the front half bright
	var tilt: float = -0.38
	var steps: int = 64
	for i in range(steps):
		var a0: float = TAU * float(i) / float(steps)
		var a1: float = TAU * float(i + 1) / float(steps)
		var p0: Vector2 = c + Vector2(cos(a0) * 70.0, sin(a0) * 22.0).rotated(tilt)
		var p1: Vector2 = c + Vector2(cos(a1) * 70.0, sin(a1) * 22.0).rotated(tilt)
		var front: bool = sin((a0 + a1) * 0.5) > 0.0
		_emblem.draw_line(p0, p1, Color(UI.C_ACCENT, 0.95 if front else 0.25), 2.0 if front else 1.2)
	# the satellite moving along the orbit
	var a: float = _t * 0.8
	var sp: Vector2 = c + Vector2(cos(a) * 70.0, sin(a) * 22.0).rotated(tilt)
	var behind: bool = sin(a) < 0.0 and sp.distance_to(c) < 44.0
	if behind:
		return
	_emblem.draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(0.92, 0.94, 0.98))
	_emblem.draw_rect(Rect2(sp - Vector2(17, 2.5), Vector2(10, 5)), Color(0.30, 0.55, 0.95))
	_emblem.draw_rect(Rect2(sp + Vector2(7, -2.5), Vector2(10, 5)), Color(0.30, 0.55, 0.95))
	_emblem.draw_circle(sp, 14.0, Color(UI.C_ACCENT, 0.12))
