extends Control
## Puzzle 4 chart: one bar per job along a day scale, with a red line on launch day.
## Call set_data(bars, launch_day). bars = Array of { "label", "start", "end" }.
## A bar that ends after launch day is drawn red.

const UI = preload("res://scripts/ui/ui.gd")

const MAX_DAY: float = 240.0
const LABEL_W: float = 80.0
const PAD_R: float = 16.0
const PAD_T: float = 28.0
const PAD_B: float = 26.0

var _bars: Array = []
var _launch_day: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(612.0, 138.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(bars: Array, launch_day: int) -> void:
	_bars = bars
	_launch_day = launch_day
	queue_redraw()


func _x(day: float) -> float:
	return LABEL_W + clampf(day / MAX_DAY, 0.0, 1.0) * (size.x - LABEL_W - PAD_R)


func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.C_DEEP)
	# day grid
	var day: int = 0
	while day <= int(MAX_DAY):
		var gx: float = _x(float(day))
		draw_line(Vector2(gx, PAD_T), Vector2(gx, size.y - PAD_B), Color(1, 1, 1, 0.12), 1.0)
		_text(Vector2(gx - 10.0, size.y - 8.0), str(day), 12, UI.C_MUTED)
		day += 40
	_text(Vector2(LABEL_W - 46.0, size.y - 8.0), "Day", 12, UI.C_MUTED)
	# the bars
	var rows: int = maxi(1, _bars.size())
	var row_h: float = (size.y - PAD_T - PAD_B) / float(rows)
	var colors: Array = [UI.C_BORDER, UI.C_CYAN, UI.C_ORANGE, UI.C_GREEN]
	for i in range(_bars.size()):
		var bar: Dictionary = _bars[i]
		var start: float = float(bar.get("start", 0))
		var finish: float = float(bar.get("end", 0))
		var top: float = PAD_T + float(i) * row_h
		_text(Vector2(8.0, top + row_h * 0.5 + 5.0), str(bar.get("label", "")), 14, UI.C_TEXT)
		var color: Color = colors[i % colors.size()]
		if finish > float(_launch_day):
			color = UI.C_RED
		var rect: Rect2 = Rect2(Vector2(_x(start), top + 6.0), Vector2(maxf(2.0, _x(finish) - _x(start)), row_h - 12.0))
		draw_rect(rect, color)
		if rect.size.x > 90.0:
			_text(Vector2(rect.position.x + 6.0, rect.position.y + rect.size.y * 0.5 + 5.0), "day %d to %d" % [int(start), int(finish)], 12, UI.C_OUTLINE)
	# launch day line
	var lx: float = _x(float(_launch_day))
	draw_line(Vector2(lx, PAD_T - 6.0), Vector2(lx, size.y - PAD_B), UI.C_RED, 3.0)
	_text(Vector2(lx - 50.0, PAD_T - 10.0), "Launch day %d" % _launch_day, 13, UI.C_RED)
