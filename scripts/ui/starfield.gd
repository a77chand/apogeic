extends Control
## The space background used when art/backgrounds/bg_space.png is missing: a deep blue
## gradient, a few soft coloured nebula glows, and twinkling stars. All code-drawn.
## The stars come from a fixed formula, so the sky is the same every run.

const STAR_COUNT: int = 140
const COLORS: Array = [Color(1, 1, 1), Color(1.0, 0.95, 0.75), Color(0.75, 0.85, 1.0), Color(0.85, 0.75, 1.0)]

var _time: float = 0.0
var _since_draw: float = 0.0
var _stars: Array = []   # each: [x 0..1, y 0..1, radius, phase, speed, colour index]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var seed_value: int = 4242
	for i in range(STAR_COUNT):
		var vals: Array = []
		for k in range(5):
			seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
			vals.append(float(seed_value) / float(0x7fffffff))
		_stars.append([vals[0], vals[1], 0.6 + vals[2] * 1.7, vals[3] * TAU, 0.6 + vals[4] * 1.8, i % COLORS.size()])


func _process(delta: float) -> void:
	_time += delta
	_since_draw += delta
	if _since_draw >= 0.08:     # about 12 redraws a second is plenty for twinkling
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	var top: Color = Color(0.03, 0.07, 0.18)
	var bottom: Color = Color(0.09, 0.07, 0.24)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), PackedColorArray([top, top, bottom, bottom]))
	_glow(Vector2(size.x * 0.12, size.y * 0.22), size.y * 0.55, Color(0.45, 0.30, 0.85))   # purple
	_glow(Vector2(size.x * 0.88, size.y * 0.78), size.y * 0.60, Color(0.10, 0.60, 0.65))   # teal
	_glow(Vector2(size.x * 0.62, size.y * 0.05), size.y * 0.40, Color(0.20, 0.35, 0.85))   # blue
	for item in _stars:
		var s: Array = item
		var twinkle: float = 0.55 + 0.45 * sin(_time * float(s[4]) + float(s[3]))
		var c: Color = COLORS[int(s[5])]
		c.a = twinkle
		draw_circle(Vector2(float(s[0]) * size.x, float(s[1]) * size.y), float(s[2]), c)


## A soft round glow: stacked circles that get fainter towards the edge.
func _glow(centre: Vector2, radius: float, color: Color) -> void:
	for i in range(10):
		var c: Color = color
		c.a = 0.012 + 0.006 * float(i)
		draw_circle(centre, radius * (1.0 - float(i) * 0.09), c)
