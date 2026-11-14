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


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	_draw_planet()
	_draw_title()


func _draw_title() -> void:
	var font: Font = UI.pixel_font(false)   # the regular weight: the bold one read too heavy
	var fs: int = 112
	var w: float = font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = Vector2(560.0 - w * 0.5, 175)
	var cap: float = fs * 0.62   # height of a capital in this font (less than the ascent)
	# the 0 is a little ringed planet: where it sits
	var x0: float = pos.x + font.get_string_size("AP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gw: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var zero: Vector2 = Vector2(x0 + gw * 0.40, pos.y - cap * 0.5)
	# a sweeping orbit around the whole title: the far half behind the letters
	var oc: Vector2 = Vector2(560.0, pos.y - cap * 0.5)
	_swoosh(oc, w * 0.62, 70.0, -0.10, false)
	_ring(zero, gw * 0.62, cap * 0.16, -0.38, false)
	draw_circle(zero, cap * 0.22, Color(0.30, 0.55, 0.95))
	draw_circle(zero + Vector2(-cap * 0.06, -cap * 0.06), cap * 0.12, Color(0.45, 0.70, 1.0))
	# stepped shadow, a few pixels down and right, like an old arcade cabinet
	for i in range(3, 0, -1):
		draw_string(font, pos + Vector2(i * 3, i * 3), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_SHADOW, 0.5 + 0.15 * i))
	draw_string(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_CREAM)
	_ring(zero, gw * 0.62, cap * 0.16, -0.38, true)
	_swoosh(oc, w * 0.62, 70.0, -0.10, true)
	# a bright star at the top of the orbit, gently pulsing
	var star: Vector2 = oc + Vector2(-40.0, -78.0)
	var k: float = 0.75 + 0.25 * sin(_t * 2.2)
	draw_circle(star, 14.0 * k, Color(1.0, 0.75, 0.45, 0.18))
	draw_line(star - Vector2(26 * k, 0), star + Vector2(26 * k, 0), Color(1.0, 0.85, 0.6, 0.9), 2.0)
	draw_line(star - Vector2(0, 18 * k), star + Vector2(0, 18 * k), Color(1.0, 0.85, 0.6, 0.9), 2.0)
	draw_circle(star, 3.5, Color(1, 0.95, 0.85))
	var strap: String = "D E S I G N    ·    L A U N C H    ·    L E A R N"
	var ss: int = 16
	var sw: float = font.get_string_size(strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	draw_string(font, Vector2(560.0 - sw * 0.5, 232), strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(UI.C_ACCENT, 0.9))


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


## A pixel planet: each square is coloured by light direction and a fixed noise pattern
## that slides sideways, so the surface turns slowly.
func _draw_planet() -> void:
	var c: Vector2 = planet_centre
	var r: float = planet_radius
	var light: Vector2 = Vector2(-0.7, -0.6).normalized()
	var shades: Array = [Color(0.16, 0.10, 0.27), Color(0.27, 0.18, 0.42), Color(0.42, 0.31, 0.60), Color(0.58, 0.47, 0.74), Color(0.72, 0.63, 0.84)]
	var n: int = int(r / PX) + 1
	var spin: float = _t * 1.2
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var d: Vector2 = Vector2(gx, gy) * PX
			if d.length() > r:
				continue
			var p: Vector2 = c + d
			if p.y > size.y or p.y + PX < 0.0:
				continue
			var nz: Vector2 = d / r
			var z: float = sqrt(max(0.0, 1.0 - nz.length_squared()))
			var lit: float = clamp(nz.dot(light) * 0.9 + z * 0.35, -1.0, 1.0)
			# surface pattern: round craters (dark floor, lit rim) that move with the spin
			var u: float = float(gx) + spin
			var level: float = (lit + 1.0) * 2.2
			var cu: float = fposmod(u, 9.0) - 4.5
			var cv: float = fposmod(float(gy) + floor(u / 9.0) * 3.0, 8.0) - 4.0
			var cr: float = 2.2 + float(abs(hash(Vector2i(int(floor(u / 9.0)), int(floor((float(gy) + floor(u / 9.0) * 3.0) / 8.0))))) % 3)
			var cd: float = Vector2(cu, cv).length()
			if cd < cr - 0.6:
				level -= 1.1
			elif cd < cr + 0.4:
				level += 0.5
			var idx: int = clampi(int(level), 0, shades.size() - 1)
			draw_rect(Rect2(p, Vector2(PX, PX)), shades[idx])
	# a soft glowing rim on the lit side
	for i in range(4):
		draw_arc(c, r + 3.0 + float(i) * 3.0, PI * 1.02, PI * 1.62, 48, Color(0.78, 0.70, 1.0, 0.45 - 0.1 * float(i)), 3.0)
	# the orbit and a satellite on it
	var tilt: float = -0.22
	var rx: float = r * 1.45
	var ry: float = r * 0.32
	var steps: int = 90
	for i in range(steps):
		if i % 2 == 1:
			continue
		var a: float = TAU * float(i) / float(steps)
		var q: Vector2 = c + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt)
		var front: bool = sin(a) > 0.0
		if not front and q.distance_to(c) < r:
			continue
		draw_rect(Rect2(q.snapped(Vector2(4, 4)), Vector2(4, 4)), Color(UI.C_ACCENT, 0.8 if front else 0.3))
	var sa: float = _t * 0.35 + PI
	var sp: Vector2 = c + Vector2(cos(sa) * rx, sin(sa) * ry).rotated(tilt)
	if sin(sa) < 0.0 and sp.distance_to(c) < r:
		return
	sp = sp.snapped(Vector2(4, 4))
	draw_rect(Rect2(sp - Vector2(6, 6), Vector2(12, 12)), C_CREAM)
	draw_rect(Rect2(sp - Vector2(22, 3), Vector2(12, 6)), Color(0.30, 0.55, 0.95))
	draw_rect(Rect2(sp + Vector2(10, -3), Vector2(12, 6)), Color(0.30, 0.55, 0.95))
