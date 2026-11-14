extends Control
## Pictures drawn in code, used when the real PNG has not arrived yet.
## UI.picture() calls Sprites.make() whenever art/<folder>/<name>.png is missing and
## <name> is in KINDS below, so the moment the artists add a PNG with that name, the PNG
## replaces the drawing. Colours come from the art guide palette.
## Everything is plain shapes (no textures), so it works in the web build.

const NAVY: Color = Color(0.043, 0.114, 0.227)
const OUTLINE: Color = Color(0.027, 0.067, 0.122)
const SOFT_WHITE: Color = Color(0.949, 0.961, 0.980)
const METAL: Color = Color(0.659, 0.698, 0.757)
const METAL_LIGHT: Color = Color(0.835, 0.863, 0.902)
const METAL_DARK: Color = Color(0.357, 0.396, 0.467)
const SOLAR: Color = Color(0.169, 0.365, 0.659)
const SOLAR_LIGHT: Color = Color(0.310, 0.525, 0.839)
const SOLAR_DARK: Color = Color(0.106, 0.247, 0.471)
const GOLD: Color = Color(0.851, 0.643, 0.255)
const GOLD_DARK: Color = Color(0.651, 0.463, 0.122)
const ROCKET_WHITE: Color = Color(0.902, 0.918, 0.941)
const ROCKET_RED: Color = Color(0.878, 0.294, 0.294)
const YELLOW: Color = Color(0.961, 0.784, 0.259)
const ORANGE: Color = Color(0.949, 0.549, 0.157)
const CYAN: Color = Color(0.247, 0.816, 0.878)
const PURPLE: Color = Color(0.608, 0.482, 0.878)
const TEAL: Color = Color(0.180, 0.769, 0.714)
const GREEN: Color = Color(0.357, 0.761, 0.478)
const OCEAN: Color = Color(0.169, 0.424, 0.839)
const LAND: Color = Color(0.298, 0.686, 0.416)

## Names (file names without .png) that can be drawn.
const KINDS: Array = [
	"earth_large", "ground_station", "spacecraft_marker", "cubesat_1u", "cubesat_3u", "cubesat_6u",
	"rocket_small", "rocket_medium", "rocket_heavy", "bg_launch_pad", "bg_earth_orbit",
	"part_solar_small", "part_solar_large", "part_battery", "part_camera", "part_spectrometer",
	"part_antenna_small", "part_antenna_large", "icon_health", "ui_logo",
]

var kind: String = ""
## Radians per second the Earth turns (0 = still). The ops screen turns it on.
var spin_speed: float = 0.0
var _phase: float = 0.0
var _since_draw: float = 0.0
var _clock: float = 0.0
## Part ids fitted on the live satellite (only used by kind "cubesat_live").
var parts: Array = []
## 0 = panels folded, 1 = fully unfolded. Setting it redraws, so a Tween can animate it.
var unfold: float = 1.0:
	set(value):
		unfold = value
		queue_redraw()


static func make(kind_name: String, pic_size: Vector2) -> Control:
	var s: Control = load("res://scripts/ui/sprites.gd").new()
	s.set("kind", kind_name)
	s.custom_minimum_size = pic_size
	s.size = pic_size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## The satellite that shows the parts you have fitted (workshop centre).
static func live_satellite(pic_size: Vector2) -> Control:
	return make("cubesat_live", pic_size)


func _process(delta: float) -> void:
	_clock += delta
	if spin_speed > 0.0:
		_phase += delta * spin_speed
		_since_draw += delta
		if _since_draw >= 0.05:   # redraw about 20 times a second
			_since_draw = 0.0
			queue_redraw()
	elif kind == "cubesat_live":
		pivot_offset = size / 2.0
		rotation = sin(_clock * 0.7) * 0.03   # the satellite sways a little, as if floating


func set_parts(part_ids: Array) -> void:
	if part_ids == parts:
		return
	parts = part_ids.duplicate()
	queue_redraw()
	# fold the panels away and unfold them again, so a change is easy to notice
	var tween: Tween = create_tween()
	tween.tween_property(self, "unfold", 0.35, 0.0)
	tween.tween_property(self, "unfold", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	match kind:
		"earth_large":
			if spin_speed > 0.0:
				_earth_spin(Vector2(size.x * 0.5, size.y * 0.5), minf(size.x, size.y) * 0.44, _phase)
			else:
				_earth(Vector2(size.x * 0.5, size.y * 0.5), minf(size.x, size.y) * 0.44)
		"ground_station": _ground_station()
		"spacecraft_marker": _marker()
		"cubesat_1u": _satellite(["solar_small", "camera_std", "radio_uhf"], 0.55, 1.0)
		"cubesat_3u": _satellite(["solar_small", "camera_std", "radio_sband"], 1.0, 1.0)
		"cubesat_6u": _satellite(["solar_large", "camera_std", "radio_sband", "antenna_big"], 1.35, 1.0)
		"cubesat_live": _satellite(parts, 1.0, unfold)
		"rocket_small": _rocket(0.15, false)
		"rocket_medium": _rocket(0.19, false)
		"rocket_heavy": _rocket(0.21, true)
		"bg_launch_pad": _launch_pad()
		"bg_earth_orbit": _orbit_bg()
		"ui_logo": _logo()
		_: _part_icon(kind)


# ---------------------------------------------------------------- helpers

func _p(u: float, v: float) -> Vector2:
	return Vector2(size.x * u, size.y * v)


func _rect(u: float, v: float, w: float, h: float, fill: Color, line: bool = true) -> void:
	var r: Rect2 = Rect2(_p(u, v), Vector2(size.x * w, size.y * h))
	draw_rect(r, fill)
	if line:
		draw_rect(r, OUTLINE, false, 2.0)


func _poly(points: Array, fill: Color, line: bool = true) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for item in points:
		var pt: Vector2 = item
		pts.append(_p(pt.x, pt.y))
	draw_colored_polygon(pts, fill)
	if line:
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, OUTLINE, 2.0)


# ---------------------------------------------------------------- Earth, ground, marker

func _earth(c: Vector2, r: float) -> void:
	for i in range(6):  # soft atmosphere glow
		draw_circle(c, r * (1.16 - 0.025 * float(i)), Color(0.35, 0.65, 1.0, 0.045 + 0.012 * float(i)))
	draw_circle(c, r, OCEAN)
	var land: Array = [
		[Vector2(-0.55, -0.25), Vector2(-0.30, -0.50), Vector2(-0.05, -0.40), Vector2(-0.12, -0.15), Vector2(-0.30, 0.05), Vector2(-0.50, 0.00)],
		[Vector2(0.10, -0.05), Vector2(0.38, -0.20), Vector2(0.60, 0.05), Vector2(0.50, 0.38), Vector2(0.25, 0.55), Vector2(0.12, 0.30)],
		[Vector2(-0.35, 0.35), Vector2(-0.15, 0.30), Vector2(-0.05, 0.55), Vector2(-0.25, 0.68)],
		[Vector2(0.05, -0.68), Vector2(0.30, -0.62), Vector2(0.22, -0.48), Vector2(0.02, -0.52)],
	]
	for blob in land:
		var pts: PackedVector2Array = PackedVector2Array()
		for item in blob:
			var v: Vector2 = item
			pts.append(c + v * r)
		draw_colored_polygon(pts, LAND)
	for cloud in [[-0.30, -0.62, 0.11], [-0.18, -0.58, 0.09], [0.35, 0.62, 0.10], [0.45, 0.55, 0.08], [-0.62, 0.20, 0.09], [0.12, -0.20, 0.07]]:
		draw_circle(c + Vector2(float(cloud[0]), float(cloud[1])) * r, float(cloud[2]) * r, Color(1, 1, 1, 0.85))
	draw_circle(c + Vector2(-0.30, -0.32) * r, r * 0.55, Color(1, 1, 1, 0.10))          # sunlit highlight
	draw_circle(c + Vector2(-0.22, -0.24) * r, r * 0.30, Color(1, 1, 1, 0.08))
	draw_arc(c, r, 0.0, TAU, 64, Color(0.6, 0.85, 1.0, 0.7), 2.0)


## Continents as longitude/latitude points (degrees). They are projected onto a ball, so
## turning the phase makes the Earth rotate, with land sliding off one edge and onto the other.
const CONTINENTS: Array = [
	[[-125, 50], [-95, 60], [-70, 48], [-80, 25], [-97, 18], [-78, 8], [-60, -5], [-50, -20], [-65, -40], [-72, -55], [-78, -20], [-90, 5], [-105, 20], [-118, 33]],
	[[-10, 36], [10, 52], [40, 55], [55, 40], [50, 12], [40, -5], [32, -28], [18, -34], [8, -5], [-5, 5], [-17, 15], [-15, 30]],
	[[60, 50], [90, 65], [130, 60], [150, 45], [120, 25], [105, 8], [90, 22], [75, 10], [68, 25], [55, 35]],
	[[114, -22], [135, -12], [152, -25], [146, -38], [130, -33], [115, -34]],
]
const CLOUDS: Array = [[-100, 40], [-60, -20], [20, 10], [70, 35], [130, -5], [-150, 15], [160, 50], [0, -45]]


func _earth_spin(c: Vector2, r: float, phase: float) -> void:
	for i in range(6):
		draw_circle(c, r * (1.16 - 0.025 * float(i)), Color(0.35, 0.65, 1.0, 0.045 + 0.012 * float(i)))
	draw_circle(c, r, OCEAN)
	for item in CONTINENTS:
		var pts: PackedVector2Array = PackedVector2Array()
		var any_front: bool = false
		for pair in item:
			var lon: float = deg_to_rad(float(pair[0])) - phase
			var lat: float = deg_to_rad(float(pair[1]))
			var x: float = cos(lat) * sin(lon)
			var y: float = sin(lat)
			var z: float = cos(lat) * cos(lon)
			if z > 0.0:
				any_front = true
			elif Vector2(x, y).length() > 0.001:
				var edge: Vector2 = Vector2(x, y).normalized()   # behind the limb: pin it to the edge
				x = edge.x
				y = edge.y
			pts.append(c + Vector2(x, -y) * r)
		if any_front and Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, LAND)
	for cloud in CLOUDS:
		var lon: float = deg_to_rad(float(cloud[0])) - phase * 1.25   # clouds drift a little faster
		var lat: float = deg_to_rad(float(cloud[1]))
		var z: float = cos(lat) * cos(lon)
		if z > 0.15:
			var p: Vector2 = c + Vector2(cos(lat) * sin(lon), -sin(lat)) * r
			draw_circle(p, r * 0.085 * (0.6 + z * 0.6), Color(1, 1, 1, 0.55 + 0.3 * z))
			draw_circle(p + Vector2(r * 0.07, r * 0.02), r * 0.06 * (0.6 + z * 0.6), Color(1, 1, 1, 0.5 + 0.3 * z))
	draw_circle(c + Vector2(-0.30, -0.32) * r, r * 0.55, Color(1, 1, 1, 0.10))
	draw_circle(c + Vector2(-0.22, -0.24) * r, r * 0.30, Color(1, 1, 1, 0.08))
	for i in range(8):   # the far edge gets darker, so it reads as a ball
		draw_arc(c, r * (0.99 - 0.035 * float(i)), -0.15 * PI, 0.85 * PI, 24, Color(0.01, 0.04, 0.14, 0.05), r * 0.07)
	draw_arc(c, r, 0.0, TAU, 64, Color(0.6, 0.85, 1.0, 0.7), 2.0)


func _ground_station() -> void:
	_rect(0.18, 0.66, 0.64, 0.30, METAL)
	_rect(0.40, 0.76, 0.20, 0.20, METAL_DARK)
	_rect(0.24, 0.72, 0.10, 0.10, CYAN, false)
	draw_line(_p(0.5, 0.66), _p(0.5, 0.45), METAL_DARK, 4.0)
	_poly([Vector2(0.22, 0.20), Vector2(0.78, 0.20), Vector2(0.64, 0.42), Vector2(0.36, 0.42)], METAL_LIGHT)
	draw_line(_p(0.5, 0.20), _p(0.5, 0.05), METAL_DARK, 3.0)
	draw_circle(_p(0.5, 0.05), size.x * 0.035, ORANGE)


func _marker() -> void:
	_rect(0.05, 0.40, 0.30, 0.20, SOLAR)
	_rect(0.65, 0.40, 0.30, 0.20, SOLAR)
	draw_line(_p(0.20, 0.40), _p(0.20, 0.60), SOLAR_LIGHT, 1.0)
	draw_line(_p(0.80, 0.40), _p(0.80, 0.60), SOLAR_LIGHT, 1.0)
	_rect(0.35, 0.30, 0.30, 0.40, GOLD)
	draw_line(_p(0.5, 0.30), _p(0.5, 0.12), METAL_LIGHT, 2.0)
	draw_circle(_p(0.5, 0.10), size.x * 0.045, CYAN)


# ---------------------------------------------------------------- the satellite

## body_scale makes the body taller for bigger craft; fold is how far the panels are open.
func _satellite(fitted: Array, body_scale: float, fold: float) -> void:
	var bh: float = clampf(0.50 * body_scale, 0.30, 0.74)
	var top: float = 0.5 - bh / 2.0
	var bx: float = 0.34
	var bw: float = 0.32
	var large: bool = fitted.has("solar_large")
	var has_panels: bool = large or fitted.has("solar_small")
	if has_panels:
		var pw: float = (0.27 if large else 0.17) * fold
		var ph: float = (bh * 0.9 if large else bh * 0.7)
		var py: float = 0.5 - ph / 2.0
		for side in [-1, 1]:
			var x0: float = bx - pw if side < 0 else bx + bw
			draw_line(_p(bx if side < 0 else bx + bw, 0.5), _p(x0 + (pw if side < 0 else 0.0), 0.5), METAL_DARK, 4.0)
			_rect(x0, py, pw, ph, SOLAR)
			_poly([Vector2(x0, py), Vector2(x0 + pw * 0.55, py), Vector2(x0, py + ph * 0.55)], Color(1, 1, 1, 0.16), false)
			_rect(x0, py + ph * 0.85, pw, ph * 0.15, Color(0, 0, 0, 0.22), false)
			var cols: int = 5 if large else 3
			for i in range(1, cols):
				var gx: float = x0 + pw * float(i) / float(cols)
				draw_line(_p(gx, py), _p(gx, py + ph), SOLAR_LIGHT, 1.0)
			draw_line(_p(x0, py + ph * 0.5), _p(x0 + pw, py + ph * 0.5), SOLAR_LIGHT, 1.0)
	# body: gold foil with metal frame and cube divisions
	_rect(bx, top, bw, bh, GOLD)
	var cubes: int = maxi(1, int(round(bh / 0.17)))
	for i in range(1, cubes):
		var gy: float = top + bh * float(i) / float(cubes)
		draw_line(_p(bx, gy), _p(bx + bw, gy), GOLD_DARK, 2.0)
	_poly([Vector2(bx, top), Vector2(bx + bw * 0.7, top), Vector2(bx, top + bh * 0.55)], Color(1, 1, 1, 0.20), false)
	_rect(bx, top + bh * 0.84, bw, bh * 0.16, Color(0, 0, 0, 0.20), false)
	_rect(bx, top, 0.02, bh, METAL, false)
	_rect(bx + bw - 0.02, top, 0.02, bh, METAL, false)
	var cx: float = bx + bw / 2.0
	var cy: float = 0.5
	if fitted.has("camera_std"):
		draw_circle(_p(cx, cy), size.y * 0.085, OUTLINE)
		draw_circle(_p(cx, cy), size.y * 0.065, Color(0.10, 0.20, 0.45))
		draw_circle(_p(cx - 0.012, cy - 0.02), size.y * 0.02, Color(0.75, 0.9, 1.0, 0.9))
	if fitted.has("spectrometer"):
		_poly([Vector2(cx - 0.05, cy + 0.07), Vector2(cx + 0.05, cy + 0.07), Vector2(cx, cy - 0.07)], METAL_LIGHT)
		for i in range(3):
			var colors: Array = [ROCKET_RED, YELLOW, CYAN]
			draw_line(_p(cx + 0.02, cy - 0.01 + 0.025 * float(i)), _p(cx + 0.09, cy - 0.04 + 0.04 * float(i)), colors[i], 2.0)
	if fitted.has("battery_small") or fitted.has("battery_std"):
		var bat_w: float = 0.11 if fitted.has("battery_std") else 0.07
		_rect(bx + 0.025, top + bh - 0.14, bat_w, 0.09, GREEN)
		draw_line(_p(bx + 0.025 + bat_w * 0.55, top + bh - 0.135), _p(bx + 0.025 + bat_w * 0.35, top + bh - 0.085), YELLOW, 2.0)
	if fitted.has("shielding"):
		_rect(bx - 0.012, top + 0.03, 0.012, bh - 0.06, METAL_DARK, false)
		_rect(bx + bw, top + 0.03, 0.012, bh - 0.06, METAL_DARK, false)
	if fitted.has("radio_uhf"):
		draw_line(_p(cx, top), _p(cx, top - 0.20), METAL_LIGHT, 3.0)
		draw_circle(_p(cx, top - 0.21), size.y * 0.02, CYAN)
	if fitted.has("radio_sband"):
		_rect(cx - 0.07, top - 0.045, 0.14, 0.045, PURPLE)
		for i in range(1, 3):
			draw_arc(_p(cx, top - 0.05), size.y * 0.07 * float(i), -0.85 * PI, -0.15 * PI, 12, PURPLE, 2.0)
	if fitted.has("antenna_big"):
		draw_line(_p(bx + bw - 0.04, top), _p(bx + bw + 0.02, top - 0.14), METAL_DARK, 3.0)
		_poly([Vector2(bx + bw - 0.04, top - 0.24), Vector2(bx + bw + 0.12, top - 0.20), Vector2(bx + bw + 0.02, top - 0.08)], METAL_LIGHT)
	if fitted.has("ground2"):
		_rect(bx + 0.02, top + bh + 0.04, 0.10, 0.07, METAL, false)
		draw_arc(_p(bx + 0.07, top + bh + 0.04), size.y * 0.06, PI, TAU, 10, ORANGE, 3.0)


# ---------------------------------------------------------------- rockets

func _rocket(half_width: float, boosters: bool) -> void:
	var x0: float = 0.5 - half_width
	var x1: float = 0.5 + half_width
	if boosters:
		for side in [-1, 1]:
			var bx: float = 0.5 + float(side) * (half_width + 0.085) - 0.045
			_rect(bx, 0.34, 0.09, 0.50, METAL_LIGHT)
			_poly([Vector2(bx, 0.34), Vector2(bx + 0.09, 0.34), Vector2(bx + 0.045, 0.26)], ROCKET_RED)
	_poly([Vector2(x0, 0.18), Vector2(x1, 0.18), Vector2(0.5, 0.02)], ROCKET_RED)     # nose cone
	_rect(x0, 0.18, half_width * 2.0, 0.66, ROCKET_WHITE)                             # body
	_rect(x0, 0.18, half_width * 0.55, 0.66, Color(1, 1, 1, 0.45), false)             # light from the left
	_rect(x1 - half_width * 0.6, 0.18, half_width * 0.6, 0.66, Color(0.1, 0.15, 0.35, 0.20), false)  # shade on the right
	_rect(x0, 0.40, half_width * 2.0, 0.07, ROCKET_RED, false)                        # stripe
	draw_circle(_p(0.5, 0.29), size.x * 0.06, OUTLINE)                                # window
	draw_circle(_p(0.5, 0.29), size.x * 0.045, CYAN)
	for side in [-1, 1]:                                                              # fins
		var fx: float = x0 if side < 0 else x1
		var out: float = fx + float(side) * 0.13
		_poly([Vector2(fx, 0.66), Vector2(out, 0.86), Vector2(fx, 0.84)], ROCKET_RED)
	_rect(0.5 - half_width * 0.6, 0.84, half_width * 1.2, 0.03, METAL_DARK, false)   # engine bell


# ---------------------------------------------------------------- backgrounds and logo

## The launch scene. The bottom 720 px is the pad; anything above that (when the control is
## taller) is more sky, fading smoothly from sunset to the colour of space, so when the camera
## pulls away there is no seam anywhere.
func _launch_pad() -> void:
	var h: float = 720.0
	var top: float = maxf(0.0, size.y - h)
	var horizon: float = top + h * 0.88
	var space_col: Color = Color(0.03, 0.07, 0.18)
	var high: Color = Color(0.07, 0.09, 0.26)
	var mid: Color = Color(0.34, 0.20, 0.36)
	var low: Color = Color(0.98, 0.55, 0.35)
	_band(0.0, top + h * 0.10, space_col, high)
	_band(top + h * 0.10, top + h * 0.50, high, mid)
	_band(top + h * 0.50, horizon, mid, low)
	var seed_value: int = 777
	for i in range(int(size.y / 9.0)):   # stars, fading out towards the horizon
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var sx: float = float(seed_value % 10000) / 10000.0 * size.x
		seed_value = (seed_value * 1103515245 + 12345) & 0x7fffffff
		var sy: float = float(seed_value % 10000) / 10000.0 * (top + h * 0.55)
		var fade: float = clampf(1.0 - (sy - top) / (h * 0.55), 0.0, 1.0) if sy > top else 1.0
		draw_circle(Vector2(sx, sy), 0.8 + float(i % 3) * 0.5, Color(1, 1, 1, 0.65 * fade))
	draw_circle(Vector2(size.x * 0.18, top + h * 0.84), h * 0.16, Color(1.0, 0.85, 0.55, 0.35))
	draw_rect(Rect2(0.0, horizon, size.x, size.y - horizon), Color(0.20, 0.24, 0.30))
	draw_rect(Rect2(size.x * 0.30, horizon, size.x * 0.40, h * 0.03), METAL_DARK)
	var tx: float = size.x * 0.18
	var tw: float = size.x * 0.045
	draw_line(Vector2(tx, horizon), Vector2(tx, top + h * 0.18), METAL_DARK, 6.0)
	draw_line(Vector2(tx + tw, horizon), Vector2(tx + tw, top + h * 0.18), METAL_DARK, 6.0)
	for i in range(14):
		var ty: float = horizon - float(i) * h * 0.05
		draw_line(Vector2(tx, ty), Vector2(tx + tw, ty - h * 0.05), METAL, 2.0)
	for i in range(3):
		var ay: float = top + h * (0.30 + float(i) * 0.12)
		draw_line(Vector2(tx + tw, ay), Vector2(tx + size.x * 0.17, ay), METAL_LIGHT, 4.0)
	draw_circle(Vector2(tx + tw * 0.45, top + h * 0.17), 6.0, ROCKET_RED)


## A vertical colour gradient between two heights.
func _band(y0: float, y1: float, c0: Color, c1: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c0, c1, c1]))


func _orbit_bg() -> void:
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 2.05)
	var r: float = size.y * 1.38
	for i in range(8):
		draw_circle(c, r + float(i) * 5.0, Color(0.35, 0.65, 1.0, 0.03 + 0.012 * float(8 - i)))
	draw_circle(c, r, OCEAN)
	for blob in [[0.18, 0.80, 0.10], [0.42, 0.74, 0.07], [0.70, 0.78, 0.12], [0.88, 0.86, 0.09]]:
		draw_circle(Vector2(size.x * float(blob[0]), size.y * float(blob[1])), size.y * float(blob[2]), LAND)
	draw_arc(c, r, PI * 1.18, PI * 1.82, 64, Color(0.6, 0.85, 1.0, 0.8), 3.0)


func _logo() -> void:
	var c: Vector2 = _p(0.17, 0.50)
	_earth(c, size.y * 0.30)
	draw_arc(c, size.y * 0.44, -0.9 * PI, 0.05 * PI, 40, ORANGE, 4.0)
	draw_circle(c + Vector2(cos(0.05 * PI), sin(0.05 * PI)) * size.y * 0.44, size.y * 0.04, YELLOW)
	var font: Font = ThemeDB.fallback_font
	if ResourceLoader.exists("res://art/fonts/LilitaOne-Regular.ttf"):
		font = load("res://art/fonts/LilitaOne-Regular.ttf")
	var x: float = size.x * 0.33
	var big: int = int(size.y * 0.30)
	var small: int = int(size.y * 0.20)
	# soft glow behind the words
	for i in range(6):
		draw_circle(_p(0.62, 0.50), size.y * (0.55 - 0.06 * float(i)), Color(0.25, 0.55, 1.0, 0.025))
	_title_text(font, Vector2(x, size.y * 0.44), "SPACE MISSION", small, SOFT_WHITE, Color(0.55, 0.75, 1.0))
	_title_text(font, Vector2(x, size.y * 0.80), "DESIGNER", big, Color(1.0, 0.82, 0.30), Color(1.0, 0.55, 0.15))


## Chunky title text: a drop shadow, a thick dark outline, the main colour, and the lighter
## colour nudged up a little on top, which reads as a bevelled highlight on the letters.
func _title_text(font: Font, pos: Vector2, text: String, font_size: int, top_col: Color, bottom_col: Color) -> void:
	var w: float = size.x * 0.66
	draw_string_outline(font, pos + Vector2(0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, 12, Color(0, 0, 0, 0.55))
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, 10, OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, bottom_col)
	draw_string(font, pos + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, w, font_size, Color(top_col, 0.55))


# ---------------------------------------------------------------- small icons for part cards

func _part_icon(name_key: String) -> void:
	match name_key:
		"part_solar_small", "part_solar_large":
			var cols: int = 3 if name_key == "part_solar_small" else 5
			_rect(0.10, 0.22, 0.80, 0.56, SOLAR)
			for i in range(1, cols):
				var gx: float = 0.10 + 0.80 * float(i) / float(cols)
				draw_line(_p(gx, 0.22), _p(gx, 0.78), SOLAR_LIGHT, 1.0)
			draw_line(_p(0.10, 0.50), _p(0.90, 0.50), SOLAR_LIGHT, 1.0)
			_rect(0.10, 0.74, 0.80, 0.04, GOLD, false)
		"part_battery":
			_rect(0.16, 0.30, 0.62, 0.42, GREEN)
			_rect(0.78, 0.42, 0.08, 0.18, METAL, false)
			_poly([Vector2(0.50, 0.32), Vector2(0.34, 0.54), Vector2(0.46, 0.54), Vector2(0.40, 0.70), Vector2(0.62, 0.46), Vector2(0.50, 0.46)], YELLOW, false)
		"part_camera":
			_rect(0.14, 0.30, 0.72, 0.46, METAL)
			_rect(0.24, 0.22, 0.20, 0.10, METAL_DARK, false)
			draw_circle(_p(0.5, 0.53), size.x * 0.19, OUTLINE)
			draw_circle(_p(0.5, 0.53), size.x * 0.14, Color(0.10, 0.20, 0.45))
			draw_circle(_p(0.46, 0.49), size.x * 0.045, Color(0.75, 0.9, 1.0))
		"part_spectrometer":
			_rect(0.12, 0.36, 0.38, 0.34, METAL)
			_poly([Vector2(0.50, 0.30), Vector2(0.50, 0.76), Vector2(0.74, 0.53)], METAL_LIGHT)
			var rainbow: Array = [ROCKET_RED, ORANGE, YELLOW, GREEN, CYAN]
			for i in range(5):
				draw_line(_p(0.72, 0.46 + 0.03 * float(i)), _p(0.92, 0.36 + 0.09 * float(i)), rainbow[i], 2.0)
		"part_antenna_small":
			draw_line(_p(0.5, 0.80), _p(0.5, 0.30), METAL_LIGHT, 4.0)
			draw_circle(_p(0.5, 0.26), size.x * 0.06, CYAN)
			for i in range(1, 3):
				draw_arc(_p(0.5, 0.26), size.x * 0.12 * float(i), -0.8 * PI, -0.2 * PI, 10, PURPLE, 2.0)
			_rect(0.34, 0.78, 0.32, 0.08, METAL_DARK, false)
		"part_antenna_large", "ground_station_icon":
			_poly([Vector2(0.12, 0.20), Vector2(0.88, 0.20), Vector2(0.66, 0.58), Vector2(0.34, 0.58)], METAL_LIGHT)
			draw_line(_p(0.5, 0.20), _p(0.5, 0.06), METAL_DARK, 3.0)
			draw_circle(_p(0.5, 0.06), size.x * 0.05, ORANGE)
			draw_line(_p(0.5, 0.58), _p(0.5, 0.84), METAL_DARK, 5.0)
			_rect(0.30, 0.82, 0.40, 0.08, METAL_DARK, false)
		"icon_health":
			_poly([Vector2(0.5, 0.10), Vector2(0.86, 0.24), Vector2(0.80, 0.62), Vector2(0.5, 0.90), Vector2(0.20, 0.62), Vector2(0.14, 0.24)], TEAL)
			draw_line(_p(0.5, 0.28), _p(0.5, 0.66), SOFT_WHITE, 4.0)
			draw_line(_p(0.32, 0.47), _p(0.68, 0.47), SOFT_WHITE, 4.0)
		_:
			_rect(0.1, 0.1, 0.8, 0.8, Color(0.08, 0.16, 0.29))
