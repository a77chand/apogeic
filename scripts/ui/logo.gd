extends Control
## The game's title art, drawn in code in a pixel style: the name "AP0GEIC 11" in big
## blocky letters with a purple drop shadow, and a slowly turning pixel planet under it
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
	var pos: Vector2 = Vector2(560.0 - w * 0.5, 165)
	# stepped shadow, a few pixels down and right, like an old arcade cabinet
	for i in range(3, 0, -1):
		draw_string(font, pos + Vector2(i * 3, i * 3), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_SHADOW, 0.5 + 0.15 * i))
	draw_string(font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_CREAM)
	# the pixel font draws 0 like O, so add a stepped slash corner to corner inside it
	var x0: float = pos.x + font.get_string_size("AP", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gw: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cap: float = fs * 0.62   # height of a capital in this font (less than the ascent)
	var px: float = fs / 14.0
	var steps: int = 6
	var left: float = x0 + gw * 0.18
	var right: float = x0 + gw * 0.62
	var bottom: float = pos.y - cap * 0.12 + px
	var top: float = pos.y - cap * 0.80 + px
	for k in range(steps):
		var u: float = float(k) / float(steps - 1)
		var p: Vector2 = Vector2(lerpf(left, right, u), lerpf(bottom, top, u) - px)
		draw_rect(Rect2(p + Vector2(3, 3), Vector2(px, px)), C_SHADOW)
		draw_rect(Rect2(p, Vector2(px, px)), C_CREAM)
	var strap: String = "D E S I G N    ·    L A U N C H    ·    L E A R N"
	var ss: int = 14
	var sw: float = font.get_string_size(strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
	draw_string(font, Vector2(560.0 - sw * 0.5, 210), strap, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Color(UI.C_ACCENT, 0.85))


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
			# surface pattern: craters and dark patches that move with the spin
			var u: int = int(floor(gx + spin))
			var h: int = abs(hash(Vector2i(u >> 1, gy >> 1))) % 100
			var level: float = (lit + 1.0) * 2.2
			if h < 18:
				level -= 1.0
			elif h > 92:
				level += 0.6
			var idx: int = clampi(int(level), 0, shades.size() - 1)
			draw_rect(Rect2(p, Vector2(PX, PX)), shades[idx])
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
