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


## A distant gas giant with a tilted ring, in the same pixel style as the title planet:
## warm coral and gold bands, lit from the upper left, and a pale cyan ring that passes
## behind the planet and in front of it. Square "pixels" of PIXEL size.
const PIXEL: float = 5.0


var _planet_cells: Array = []     # [Rect2, Color] for each pixel, worked out once per size
var _planet_key: Vector3 = Vector3.ZERO


func _ringed_planet(c: Vector2, r: float) -> void:
	var key: Vector3 = Vector3(c.x, c.y, r)
	if key != _planet_key:
		_planet_key = key
		_planet_cells = _build_ringed_planet(c, r)
	for item in _planet_cells:
		var cell: Array = item
		draw_rect(cell[0], cell[1])


func _build_ringed_planet(c: Vector2, r: float) -> Array:
	var out: Array = []
	var bands: Array = [Color(0.98, 0.62, 0.42), Color(1.0, 0.78, 0.50), Color(0.93, 0.45, 0.45), Color(1.0, 0.86, 0.62), Color(0.96, 0.55, 0.38)]
	var light: Vector2 = Vector2(-0.6, -0.8)
	var tilt: float = -0.32
	var ring_in: float = 1.35
	var ring_out: float = 1.95
	var n: int = int(ceil(r * ring_out / PIXEL)) + 1
	# the far half of the ring first, then the planet, then the near half
	for pass_i in range(3):
		for gy in range(-n, n + 1):
			for gx in range(-n, n + 1):
				var d: Vector2 = Vector2(gx, gy) * PIXEL
				var cell: Rect2 = Rect2(c + d - Vector2(PIXEL, PIXEL) * 0.5, Vector2(PIXEL, PIXEL))
				var on_planet: bool = d.length() <= r
				if pass_i == 1:
					if not on_planet:
						continue
					var nz: Vector2 = d / r
					var z: float = sqrt(maxf(0.0, 1.0 - nz.length_squared()))
					var lit: float = clampf(nz.dot(light.normalized()) * 0.8 + z * 0.5, -1.0, 1.0)
					var band: Color = bands[posmod(int(floor((d.y + d.x * 0.25) / (r * 0.34))), bands.size())]
					var col: Color = band.darkened(clampf(0.45 - lit * 0.45, 0.0, 0.7))
					if lit > 0.75:
						col = col.lightened(0.18)
					out.append([cell, col])
					continue
				# the ring: an ellipse band, squashed and tilted
				var q: Vector2 = d.rotated(-tilt)
				var e: float = Vector2(q.x / r, q.y / (r * 0.30)).length()
				if e < ring_in or e > ring_out:
					continue
				var front: bool = q.y > 0.0
				if (pass_i == 0 and front) or (pass_i == 2 and not front):
					continue
				if pass_i == 0 and on_planet:
					continue
				var k: float = (e - ring_in) / (ring_out - ring_in)
				var ring_col: Color = Color(0.62, 0.92, 1.0).lerp(Color(0.95, 0.82, 1.0), k)
				if absf(k - 0.55) < 0.08:
					ring_col = ring_col.darkened(0.35)   # the gap in the ring
				out.append([cell, Color(ring_col, 0.9 if front else 0.6)])
	return out


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
