extends Control
## The mission chart on the report: battery % (teal) and data delivered so far (cyan)
## across the weeks, with the goal line, and a flag where an event happened.
## Call set_data(history, goal_mb, weeks, flags, ended_early). history = one Dictionary per
## week flown: { week, battery_pct, delivered_mb }. flags = [{ "week": int, "label": String }].

const PAD_L: float = 44.0
const PAD_R: float = 52.0
const PAD_T: float = 30.0
const PAD_B: float = 26.0
const BATTERY: Color = Color(0.18, 0.77, 0.71)
const DATA: Color = Color(0.25, 0.82, 0.88)
const GOAL: Color = Color(0.95, 0.55, 0.16)
const RED: Color = Color(0.90, 0.28, 0.30)

var _history: Array = []
var _goal_mb: float = 1.0
var _weeks: int = 12
var _flags: Array = []
var _ended_early: bool = false
var _empty_text: String = "There is nothing to chart."


func _init() -> void:
	custom_minimum_size = Vector2(610.0, 160.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(history: Array, goal_mb: float, weeks: int, flags: Array, ended_early: bool, empty_text: String = "There is nothing to chart.") -> void:
	_empty_text = empty_text
	_history = history
	_goal_mb = maxf(1.0, goal_mb)
	_weeks = maxi(1, weeks)
	_flags = flags
	_ended_early = ended_early
	queue_redraw()


func _x(week: float) -> float:
	return PAD_L + (size.x - PAD_L - PAD_R) * week / float(_weeks)


func _y(fraction: float) -> float:
	return PAD_T + (size.y - PAD_T - PAD_B) * (1.0 - clampf(fraction, 0.0, 1.0))


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.15, 0.9))
	for i in range(5):  # horizontal grid
		var f: float = float(i) / 4.0
		draw_line(Vector2(PAD_L, _y(f)), Vector2(size.x - PAD_R, _y(f)), Color(1, 1, 1, 0.08), 1.0)
	for w in range(0, _weeks + 1, 2):
		draw_string(font, Vector2(_x(float(w)) - 4.0, size.y - 8.0), str(w), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.70, 0.76))
	draw_string(font, Vector2(PAD_L, 14.0), "Battery %", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BATTERY)
	draw_string(font, Vector2(size.x - PAD_R - 118.0, 14.0), "Data delivered", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DATA)
	draw_string(font, Vector2(size.x - PAD_R + 4.0, _y(1.0) + 4.0), "%d MB" % int(_goal_mb), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOAL)
	draw_dashed_line(Vector2(PAD_L, _y(1.0)), Vector2(size.x - PAD_R, _y(1.0)), GOAL, 1.5, 6.0)  # the goal
	for item in _flags:
		var flag: Dictionary = item
		var week: int = int(flag.get("week", 0))
		if week > _history.size() + 1:
			continue
		draw_dashed_line(Vector2(_x(float(week)), PAD_T), Vector2(_x(float(week)), size.y - PAD_B), Color(1.0, 0.85, 0.3, 0.5), 1.0, 4.0)
		draw_string(font, Vector2(_x(float(week)) + 3.0, PAD_T + 12.0), str(flag.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.3))
	if _history.is_empty():
		draw_string(font, Vector2(PAD_L + 10.0, size.y * 0.5), _empty_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.66, 0.70, 0.76))
		return
	var battery: PackedVector2Array = PackedVector2Array([Vector2(_x(0.0), _y(1.0))])
	var data: PackedVector2Array = PackedVector2Array([Vector2(_x(0.0), _y(0.0))])
	for item in _history:
		var rec: Dictionary = item
		var w: float = float(rec.get("week", 0))
		battery.append(Vector2(_x(w), _y(float(rec.get("battery_pct", 0.0)) / 100.0)))
		data.append(Vector2(_x(w), _y(float(rec.get("delivered_mb", 0.0)) / _goal_mb)))
	draw_polyline(battery, BATTERY, 2.5)
	draw_polyline(data, DATA, 2.5)
	for pt in battery:
		draw_circle(pt, 3.0, BATTERY)
	for pt in data:
		draw_circle(pt, 3.0, DATA)
	if _ended_early:   # a red cross where the mission stopped
		var last: Vector2 = battery[battery.size() - 1]
		draw_line(last + Vector2(-6, -6), last + Vector2(6, 6), RED, 3.0)
		draw_line(last + Vector2(-6, 6), last + Vector2(6, -6), RED, 3.0)
