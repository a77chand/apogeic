extends Control
## The game's title art, drawn in code in a pixel style: the name "AP0GEIC 11" in big
## blocky letters with a purple drop shadow (the 0 is a small ringed planet), a sweeping
## orbit round the title with a bright star, and a slowly turning cratered pixel planet
## with a satellite on a tilted orbit. Used on the title screen. If art/ui/ui_logo.png is
## added later, title.gd shows that instead.

const UI = preload("res://scripts/ui/ui.gd")

const TITLE: String = "AP0GEIC 11"
const C_CREAM: Color = Color(0.98, 0.96, 0.78)
const C_SHADOW: Color = Color(0.33, 0.22, 0.58)
const PX: float = 8.0   # size of one planet "pixel"

var planet_centre: Vector2 = Vector2(640, 700)
var planet_radius: float = 230.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


var _since_draw: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	_since_draw += delta
	# the pixel planet is thousands of squares, so redraw 30 times a second, not every frame
	# (smooth enough for a slow spin, and much lighter in a browser)
	if _since_draw >= 1.0 / 30.0:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	_draw_planet()
	_draw_title()


func _draw_title() -> void:
	var font: Font = UI.pixel_font(false)   # the regular weight: the bold one read too heavy
	var fs: int = 128
	var w: float = font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(560.0 - w * 0.5, 210)
	var cap: float = fs * 0.62   # height of a capital in this font (less than the ascent)
	# the 0 is a little ringed planet: where it sits
	var x0: float = pos.x + font.get_string_size("AP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gw: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var zero: Vector2 = Vector2(x0 + gw * 0.40, pos.y - cap * 0.5)
	# a thin, wispy orbit round the title: it starts low at the left, passes under the
	# letters (but above the strap line) and fades out behind them at the top right
	var oc: Vector2 = Vector2(560.0, pos.y - cap * 0.55)
	_wisp(oc, w * 0.60, 64.0, -0.16, false)
	_ring(zero, gw * 0.62, cap * 0.16, -0.38, false)
	draw_circle(zero, cap * 0.22, Color(0.30, 0.55, 0.95))
	draw_circle(zero + Vector2(-cap * 0.06, -cap * 0.06), cap * 0.12, Color(0.45, 0.70, 1.0))
	# soft violet glow behind the letters
	for i in range(4):
		draw_string_outline(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(float(4 - i) * 6.0), Color(0.55, 0.35, 1.0, 0.07))
	# a deep 3D block: many layers stepping down and right, dark violet at the back
	# turning magenta near the face
	var depth: int = 9
	for i in range(depth, 0, -1):
		var k: float = float(i) / float(depth)
		var col: Color = Color(0.62, 0.30, 0.90).lerp(Color(0.14, 0.08, 0.36), k)
		draw_string(font, pos + Vector2(float(i) * 2.0, float(i) * 2.0), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# the face: cream, with a warm lower half for a little shading
	draw_string(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_CREAM)
	draw_string_outline(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(1.0, 1.0, 0.95, 0.35))
	_ring(zero, gw * 0.62, cap * 0.16, -0.38, true)
	_wisp(oc, w * 0.60, 64.0, -0.16, true)
	# a bright star on the orbit, gently pulsing
	var star: Vector2 = oc + Vector2(-60.0, -70.0)
	var k2: float = 0.75 + 0.25 * sin(_t * 2.2)
	draw_circle(star, 16.0 * k2, Color(1.0, 0.70, 0.40, 0.16))
	draw_line(star - Vector2(30 * k2, 0), star + Vector2(30 * k2, 0), Color(1.0, 0.85, 0.6, 0.9), 2.0)
	draw_line(star - Vector2(0, 20 * k2), star + Vector2(0, 20 * k2), Color(1.0, 0.85, 0.6, 0.9), 2.0)
	draw_circle(star, 3.5, Color(1, 0.95, 0.85))
	var strap: String = "D E S I G N    ·    L A U N C H    ·    L E A R N"
	var ss: int = 18
	var sw: float = font.get_string_size(strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	draw_string(font, Vector2(560.0 - sw * 0.5, 296), strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(UI.C_ACCENT, 0.95))


## The title orbit as a wisp: thin at both ends and a little thicker in the middle,
## purple on the left fading to cyan, and it fades out instead of closing the loop.
## front = the half that passes in front of (below) the letters.
func _wisp(c: Vector2, rx: float, ry: float, tilt: float, front: bool) -> void:
	var n: int = 90
	var a_start: float = 0.15 * PI if front else 1.0 * PI
	var a_end: float = 1.0 * PI if front else 1.82 * PI
	for i in range(n):
		var u0: float = float(i) / float(n)
		var u1: float = float(i + 1) / float(n)
		var a0: float = lerpf(a_start, a_end, u0)
		var a1: float = lerpf(a_start, a_end, u1)
		var p0: Vector2 = c + Vector2(cos(a0) * rx, sin(a0) * ry).rotated(tilt)
		var p1: Vector2 = c + Vector2(cos(a1) * rx, sin(a1) * ry).rotated(tilt)
		# overall position round the loop (0 = right end of the front half), for colour and taper
		var g: float = (a0 - 0.15 * PI) / (1.67 * PI)
		var taper: float = sin(clampf(g, 0.0, 1.0) * PI)
		var col: Color = Color(0.40, 0.85, 1.0).lerp(Color(0.66, 0.42, 1.0), clampf(g * 1.4, 0.0, 1.0))
		var alpha: float = (0.95 if front else 0.55) * (0.25 + 0.75 * taper)
		draw_line(p0, p1, Color(col, alpha * 0.18), 10.0 * taper + 2.0)
		draw_line(p0, p1, Color(col, alpha), 1.2 + 2.2 * taper)


## Half of a tilted ellipse: front = the near half (drawn over the letters), else the far half.
func _ring(c: Vector2, rx: float, ry: float, tilt: float, front: bool) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(33):
		var a: float = (0.0 if front else PI) + PI * float(i) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	draw_polyline(pts, Color(0.75, 0.62, 1.0, 1.0 if front else 0.55), 4.0)


## The big orbit round the title, purple at one end fading to cyan, with a faint glow.
func _swoosh(c: Vector2, rx: float, ry: float, tilt: float, front: bool) -> void:
	var n: int = 64
	for i in range(n):
		var a0: float = (0.0 if front else PI) + PI * float(i) / float(n)
		var a1: float = (0.0 if front else PI) + PI * float(i + 1) / float(n)
		var p0: Vector2 = c + Vector2(cos(a0) * rx, sin(a0) * ry).rotated(tilt)
		var p1: Vector2 = c + Vector2(cos(a1) * rx, sin(a1) * ry).rotated(tilt)
		var u: float = (cos(a0) + 1.0) * 0.5
		var col: Color = Color(0.62, 0.42, 1.0).lerp(Color(0.40, 0.85, 1.0), u)
		var alpha: float = 0.9 if front else 0.45
		draw_line(p0, p1, Color(col, alpha * 0.25), 9.0)
		draw_line(p0, p1, Color(col, alpha), 3.0)


## A big pixel planet rising from the bottom-left corner, like the reference art: pale
## lavender, lit from the upper left, with round craters (dark floors, light rims) that
## drift sideways as it turns, and a glowing rim of atmosphere along its top edge. Only
## the part on screen is drawn, and it always reaches the bottom and left edges.
func _draw_planet() -> void:
	var c: Vector2 = planet_centre
	var r: float = planet_radius
	var light: Vector2 = Vector2(-0.55, -0.83).normalized()
	var shades: Array = [Color(0.22, 0.08, 0.48), Color(0.36, 0.14, 0.70), Color(0.50, 0.24, 0.88), Color(0.64, 0.38, 0.98), Color(0.76, 0.56, 1.0), Color(0.86, 0.74, 1.0)]
	var spin: float = _t * 0.9
	# a wide soft haze around the planet so it stands out from the sky
	for i in range(8):
		draw_circle(c, r + 70.0 - float(i) * 8.0, Color(0.55, 0.40, 1.0, 0.035))
	# the window can be taller or wider than 1280 x 720 (the screen stretches to fill it),
	# so draw to the edge of what is really visible, not just the design size
	var view: Vector2 = get_viewport_rect().size
	var top_row: int = int(floor((maxf(0.0, c.y - r) - c.y) / PX))
	var bottom_row: int = int(ceil((maxf(size.y, view.y) - c.y) / PX))
	for gy in range(top_row, bottom_row + 1):
		var dy: float = float(gy) * PX
		if absf(dy) > r:
			continue
		var half: float = sqrt(r * r - dy * dy)
		var gx0: int = int(floor(maxf(-half, -c.x) / PX))
		var gx1: int = int(ceil(minf(half, maxf(size.x, view.x) - c.x) / PX))
		for gx in range(gx0, gx1 + 1):
			var d: Vector2 = Vector2(float(gx) * PX, dy)
			if d.length() > r:
				continue
			var nz: Vector2 = d / r
			var z: float = sqrt(maxf(0.0, 1.0 - nz.length_squared()))
			var lit: float = clampf(nz.dot(light) * 0.85 + z * 0.45, -1.0, 1.0)
			var level: float = (lit + 0.9) * 2.6
			# round craters on a drifting grid of cells: a dark floor, a bright rim on the side
			# facing the light and a dark rim on the other, so they read as dents, not squares
			var u: float = float(gx) + spin
			var cw: float = 14.0
			var ch: float = 11.0
			var cell: Vector2i = Vector2i(int(floor(u / cw)), int(floor(float(gy) / ch)))
			var hsh: int = absi(hash(cell))
			if (hsh / 343) % 4 != 0:
				var cc: Vector2 = Vector2(float(cell.x) * cw + 4.0 + float(hsh % 6), float(cell.y) * ch + 3.0 + float((hsh / 7) % 5))
				var cr: float = 2.0 + float((hsh / 49) % 4) * 0.9
				var off: Vector2 = Vector2(u, float(gy)) - cc
				var cd: float = off.length()
				if cd < cr - 0.7:
					level -= 1.0 + (0.4 if off.dot(light) > 0.0 else 0.0)
				elif cd < cr + 0.6:
					level += 0.9 if off.dot(light) > 0.0 else -0.6
			var idx: int = clampi(int(level), 0, shades.size() - 1)
			draw_rect(Rect2(c + d, Vector2(PX, PX)), shades[idx])
	# the glowing rim of atmosphere along the top
	for i in range(9):
		var a: float = 0.6 - 0.065 * float(i)
		var glow: Color = Color(0.70, 0.88, 1.0).lerp(Color(0.72, 0.50, 1.0), float(i) / 8.0)
		draw_arc(c + Vector2(PX * 0.5, PX * 0.5), r + 2.0 + float(i) * 4.0, PI * 1.0, PI * 1.9, 128, Color(glow, maxf(0.04, a)), 4.0)
	draw_arc(c + Vector2(PX * 0.5, PX * 0.5), r + 1.0, PI * 1.05, PI * 1.7, 128, Color(0.92, 0.98, 1.0, 0.95), 3.0)
	_draw_orbit(c, r)


## A satellite on a real, tilted orbit round the planet: the near half of the orbit passes
## in front of the planet's face, the far half goes behind it (hidden where the planet is in
## the way). The satellite looks bigger on the near side, so it reads as going round, not
## sliding back and forth.
func _draw_orbit(c: Vector2, r: float) -> void:
	# centred just inside the planet's top edge, so the far half of the orbit dips behind
	# the planet and the near half passes across its face
	var oc: Vector2 = c + Vector2(-10.0, -r - 10.0)
	var rx: float = 390.0
	var ry: float = 74.0
	var tilt: float = -0.12
	# the orbit line: a dotted ring, faint behind, brighter in front
	for i in range(120):
		var a: float = TAU * float(i) / 120.0
		var p: Vector2 = oc + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt)
		var front: bool = sin(a) > 0.0
		if not front and p.distance_to(c) < r:
			continue
		if i % 2 == 0:
			var dot: Rect2 = Rect2(p.snapped(Vector2(2, 2)) - Vector2(2, 2), Vector2(4, 4))
			if front:
				draw_rect(dot.grow(1.0), Color(0.10, 0.04, 0.25, 0.8))   # dark edge so it shows on the planet
			draw_rect(dot, Color(0.55, 0.92, 1.0, 0.95 if front else 0.45))
	# the satellite: one orbit every 16 seconds
	var sa: float = _t * TAU / 16.0
	var sp: Vector2 = oc + Vector2(cos(sa) * rx, sin(sa) * ry).rotated(tilt)
	var near: bool = sin(sa) > 0.0
	if not near and sp.distance_to(c) < r + 6.0:
		return   # behind the planet
	var k: float = 0.75 + 0.45 * (0.5 + 0.5 * sin(sa))   # bigger when nearer
	sp = sp.snapped(Vector2(2, 2))
	var body: Vector2 = Vector2(12, 12) * k
	var panel: Vector2 = Vector2(16, 7) * k
	draw_circle(sp, 18.0 * k, Color(UI.C_ACCENT, 0.18))
	draw_rect(Rect2(sp - body * 0.5, body), C_CREAM)
	draw_rect(Rect2(sp - Vector2(body.x * 0.5 + panel.x + 2.0, panel.y * 0.5), panel), Color(0.30, 0.55, 0.95))
	draw_rect(Rect2(sp + Vector2(body.x * 0.5 + 2.0, -panel.y * 0.5), panel), Color(0.30, 0.55, 0.95))
