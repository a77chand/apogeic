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


## A big pixel planet rising from the bottom-left corner, like the reference art: pale
## lavender, lit from the upper left, with round craters (dark floors, light rims) that
## drift sideways as it turns, and a glowing rim of atmosphere along its top edge. Only
## the part on screen is drawn, and it always reaches the bottom and left edges.
func _draw_planet() -> void:
	var c: Vector2 = planet_centre
	var r: float = planet_radius
	var light: Vector2 = Vector2(-0.55, -0.83).normalized()
	var shades: Array = [Color(0.18, 0.11, 0.32), Color(0.30, 0.20, 0.48), Color(0.44, 0.32, 0.64), Color(0.58, 0.46, 0.78), Color(0.70, 0.60, 0.88), Color(0.80, 0.73, 0.94)]
	var spin: float = _t * 0.9
	var top_row: int = int(floor((maxf(0.0, c.y - r) - c.y) / PX))
	var bottom_row: int = int(ceil((size.y - c.y) / PX))
	for gy in range(top_row, bottom_row + 1):
		var dy: float = float(gy) * PX
		if absf(dy) > r:
			continue
		var half: float = sqrt(r * r - dy * dy)
		var gx0: int = int(floor(maxf(-half, -c.x) / PX))
		var gx1: int = int(ceil(minf(half, size.x - c.x) / PX))
		for gx in range(gx0, gx1 + 1):
			var d: Vector2 = Vector2(float(gx) * PX, dy)
			if d.length() > r:
				continue
			var nz: Vector2 = d / r
			var z: float = sqrt(maxf(0.0, 1.0 - nz.length_squared()))
			var lit: float = clampf(nz.dot(light) * 0.85 + z * 0.45, -1.0, 1.0)
			var level: float = (lit + 0.9) * 2.6
			# craters on a drifting grid of cells, each cell with its own size and place
			var u: float = float(gx) + spin
			var cell: Vector2i = Vector2i(int(floor(u / 11.0)), int(floor(float(gy) / 9.0)))
			var hsh: int = absi(hash(cell))
			var cc: Vector2 = Vector2(float(cell.x) * 11.0 + 3.0 + float(hsh % 5), float(cell.y) * 9.0 + 2.0 + float((hsh / 7) % 5))
			var cr: float = 1.6 + float((hsh / 49) % 4) * 0.8
			var cd: float = Vector2(u, float(gy)).distance_to(cc)
			if (hsh / 343) % 3 != 0:
				if cd < cr - 0.5:
					level -= 1.2
				elif cd < cr + 0.5:
					level += 0.7
			var idx: int = clampi(int(level), 0, shades.size() - 1)
			draw_rect(Rect2(c + d, Vector2(PX, PX)), shades[idx])
	# the glowing rim of atmosphere along the top
	for i in range(6):
		var a: float = 0.55 - 0.09 * float(i)
		draw_arc(c + Vector2(PX * 0.5, PX * 0.5), r + 2.0 + float(i) * 3.5, PI * 1.0, PI * 1.85, 96, Color(0.82, 0.78, 1.0, maxf(0.05, a)), 3.0)
	draw_arc(c + Vector2(PX * 0.5, PX * 0.5), r + 1.0, PI * 1.08, PI * 1.62, 96, Color(0.95, 0.95, 1.0, 0.9), 2.0)
	# a small satellite crossing above the horizon, hidden while it is behind the planet
	var oc: Vector2 = c + Vector2(0.0, -r * 0.92)
	var rx: float = r * 0.85
	var ry: float = r * 0.12
	var sa: float = _t * 0.3
	var sp: Vector2 = oc + Vector2(cos(sa) * rx, sin(sa) * ry)
	if sin(sa) < 0.0 and sp.distance_to(c) < r:
		return
	sp = sp.snapped(Vector2(4, 4))
	draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), C_CREAM)
	draw_rect(Rect2(sp - Vector2(19, 3), Vector2(11, 6)), Color(0.30, 0.55, 0.95))
	draw_rect(Rect2(sp + Vector2(8, -3), Vector2(11, 6)), Color(0.30, 0.55, 0.95))
