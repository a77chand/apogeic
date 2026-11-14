extends Control
## Puzzle 2 chart: battery level through one orbit.
## Call set_data(points, eclipse_min, period_min, min_level) and it redraws.
## points = Array of [minute, percent]. Minute 0 is eclipse entry.

const UI = preload("res://scripts/ui/ui.gd")

const PAD_L: float = 48.0
const PAD_R: float = 16.0
const PAD_T: float = 16.0
const PAD_B: float = 32.0

var _points: Array = []
var _eclipse: float = 0.0
var _period: float = 1.0
var _min_level: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(612.0, 250.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(points: Array, eclipse_min: float, period_min: float, min_level: float) -> void:
	_points = points
	_eclipse = eclipse_min
	_period = maxf(1.0, period_min)
	_min_level = min_level
	queue_redraw()


func _x(minute: float) -> float:
	return PAD_L + clampf(minute / _period, 0.0, 1.0) * (size.x - PAD_L - PAD_R)


func _y(percent: float) -> float:
	return PAD_T + (1.0 - clampf(percent, 0.0, 100.0) / 100.0) * (size.y - PAD_T - PAD_B)


func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.C_DEEP)
	# the eclipse band: the Earth blocks the Sun
	var band: Rect2 = Rect2(Vector2(_x(0.0), _y(100.0)), Vector2(_x(_eclipse) - _x(0.0), _y(0.0) - _y(100.0)))
	draw_rect(band, UI.C_OUTLINE)
	_text(Vector2(band.position.x + 8.0, band.position.y + 18.0), "Eclipse", 14, UI.C_MUTED)
	_text(Vector2(_x(_eclipse) + 8.0, band.position.y + 18.0), "Sunlight", 14, UI.C_YELLOW)
	# grid and percent labels
	for pct in [0, 25, 50, 75, 100]:
		var y: float = _y(float(pct))
		draw_line(Vector2(PAD_L, y), Vector2(size.x - PAD_R, y), Color(1, 1, 1, 0.12), 1.0)
		_text(Vector2(6.0, y + 5.0), "%d%%" % pct, 12, UI.C_MUTED)
	# minute labels
	_text(Vector2(_x(0.0), size.y - 10.0), "0 min", 12, UI.C_MUTED)
	_text(Vector2(_x(_eclipse) - 14.0, size.y - 10.0), "%d min" % int(round(_eclipse)), 12, UI.C_MUTED)
	_text(Vector2(_x(_period) - 40.0, size.y - 10.0), "%d min" % int(round(_period)), 12, UI.C_MUTED)
	# the lowest allowed level, dashed red
	var limit_y: float = _y(_min_level)
	var x: float = PAD_L
	while x < size.x - PAD_R:
		draw_line(Vector2(x, limit_y), Vector2(minf(x + 8.0, size.x - PAD_R), limit_y), UI.C_RED, 2.0)
		x += 14.0
	_text(Vector2(size.x - PAD_R - 150.0, limit_y - 6.0), "Must stay above %d%%" % int(round(_min_level)), 12, UI.C_RED)
	# the battery line
	if _points.size() < 2:
		return
	var line: PackedVector2Array = PackedVector2Array()
	for item in _points:
		var pair: Array = item
		line.append(Vector2(_x(float(pair[0])), _y(float(pair[1]))))
	draw_polyline(line, UI.C_CYAN, 3.0, true)
	for p in line:
		draw_circle(p, 5.0, UI.C_CYAN)
