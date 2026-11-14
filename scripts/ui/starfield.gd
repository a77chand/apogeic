extends Control
## The space background used when art/backgrounds/bg_space.png is missing: a deep blue
## gradient, soft nebula glows, a faint galaxy band, a distant ringed planet and a small moon,
## twinkling stars that drift, and now and then a shooting star. All code-drawn.
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
	_galaxy_band()
	_ringed_planet(Vector2(size.x * 0.885, size.y * 0.235), size.y * 0.075)
	_moon(Vector2(size.x * 0.075, size.y * 0.86), size.y * 0.028)
	for item in _stars:
		var s: Array = item
		var twinkle: float = 0.55 + 0.45 * sin(_time * float(s[4]) + float(s[3]))
		var c: Color = COLORS[int(s[5])]
		c.a = twinkle
		var drift: float = fposmod(float(s[0]) + _time * 0.0025 * float(s[2]), 1.0)   # near stars move faster
		draw_circle(Vector2(drift * size.x, float(s[1]) * size.y), float(s[2]), c)


	_shooting_star()


## A faint diagonal band of light, like the Milky Way seen from far away.
func _galaxy_band() -> void:
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.55), -0.42, Vector2(1.0, 0.16))
	for i in range(8):
		draw_circle(Vector2.ZERO, size.x * (0.62 - 0.06 * float(i)), Color(0.55, 0.62, 0.95, 0.012 + 0.004 * float(i)))
	draw_set_transform(Vector2.ZERO)


## A distant gas giant with a tilted ring. The back of the ring is drawn first, then the
## planet, then the front of the ring, so the ring wraps around it.
func _ringed_planet(c: Vector2, r: float) -> void:
	var ring: Color = Color(0.85, 0.78, 0.62, 0.55)
	draw_set_transform(c, -0.32, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, r * 1.85, PI, TAU, 48, ring, r * 0.18)
	draw_set_transform(Vector2.ZERO)
	draw_circle(c, r * 1.25, Color(0.85, 0.55, 0.40, 0.06))                # haze
	draw_circle(c, r, Color(0.78, 0.50, 0.38))
	for k in range(3):                                                  # cloud bands
		var y: float = (float(k) - 1.0) * r * 0.45
		var half: float = sqrt(maxf(0.0, r * r - y * y)) * 0.96
		draw_line(c + Vector2(-half, y), c + Vector2(half, y), Color(0.95, 0.72, 0.52, 0.55), r * 0.16)
	draw_circle(c + Vector2(-r * 0.30, -r * 0.30), r * 0.55, Color(1, 1, 1, 0.08))   # lit side
	draw_arc(c, r * 0.85, -0.15 * PI, 0.85 * PI, 24, Color(0.05, 0.02, 0.10, 0.35), r * 0.32)  # shadow side
	draw_set_transform(c, -0.32, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, r * 1.85, 0.0, PI, 48, ring, r * 0.18)
	draw_set_transform(Vector2.ZERO)


## A small, rusty moon low in the corner.
func _moon(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0.62, 0.40, 0.32))
	draw_circle(c + Vector2(r * 0.25, -r * 0.20), r * 0.22, Color(0.45, 0.28, 0.24))
	draw_circle(c + Vector2(-r * 0.30, r * 0.30), r * 0.15, Color(0.45, 0.28, 0.24))
	draw_arc(c, r * 0.80, -0.1 * PI, 0.9 * PI, 16, Color(0.02, 0.02, 0.08, 0.40), r * 0.40)


## Every 9 seconds a shooting star crosses the upper sky in under a second.
func _shooting_star() -> void:
	var cycle: float = fmod(_time, 9.0)
	if cycle > 0.8:
		return
	var p: float = cycle / 0.8
	var start: Vector2 = Vector2(size.x * 0.15, size.y * 0.08)
	var end: Vector2 = Vector2(size.x * 0.55, size.y * 0.30)
	var head: Vector2 = start.lerp(end, p)
	var tail: Vector2 = start.lerp(end, maxf(0.0, p - 0.18))
	var fade: float = sin(p * PI)
	for k in range(6):   # a tail that fades towards the back
		var a: Vector2 = tail.lerp(head, float(k) / 6.0)
		var b: Vector2 = tail.lerp(head, float(k + 1) / 6.0)
		draw_line(a, b, Color(1, 1, 1, fade * float(k + 1) / 6.0), 2.0)
	draw_circle(head, 2.0, Color(1, 1, 1, fade))


## A soft round glow: stacked circles that get fainter towards the edge.
func _glow(centre: Vector2, radius: float, color: Color) -> void:
	for i in range(10):
		var c: Color = color
		c.a = 0.012 + 0.006 * float(i)
		draw_circle(centre, radius * (1.0 - float(i) * 0.09), c)
