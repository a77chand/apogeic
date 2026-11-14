extends Control
## The interactive plan for Puzzle 4, drawn in code.
## - Click the Build bar to switch between a normal and a rushed build.
## - Click the Test bar to switch between full and short testing.
## - Drag the Licence bar left or right to choose when the paperwork starts.
## Under the plan, a money bar fills up as days pass (the team is paid every day),
## with a line at the most you can spend. It emits plan_changed when anything moves.
## The surprise days (a fault fix, a licence delay) are drawn striped at the end of their
## bar, and cursor_day draws a moving "today" line while the year is played.

const UI = preload("res://scripts/ui/ui.gd")

signal plan_changed(build_id: String, test_id: String, licence_start: int)

const LEFT: float = 96.0        # where day 0 is drawn
const ROW_H: float = 46.0
const ROWS_TOP: float = 58.0
const MAX_DAY: float = 230.0
const COLORS: Dictionary = {"Build": Color(0.30, 0.55, 0.95), "Test": Color(0.95, 0.79, 0.30), "Licence": Color(0.95, 0.55, 0.16), "Ship": Color(0.36, 0.76, 0.48)}

var _pz: Dictionary = {}
var _build_id: String = ""
var _test_id: String = ""
var _licence_start: int = 0
var _res: Dictionary = {}
var _dragging: bool = false
var _drag_offset: float = 0.0
var _hover_row: int = -1
var cursor_day: float = -1.0   # the "today" line while the year plays; -1 hides it
var locked: bool = false       # no dragging while the year plays


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(pz: Dictionary, build_id: String, test_id: String, licence_start: int) -> void:
	_pz = pz
	_build_id = build_id
	_test_id = test_id
	_licence_start = licence_start


func set_result(res: Dictionary) -> void:
	_res = res
	queue_redraw()


func _day_x(day: float) -> float:
	return LEFT + (size.x - LEFT - 20.0) * day / MAX_DAY


func _x_day(x: float) -> float:
	return (x - LEFT) / (size.x - LEFT - 20.0) * MAX_DAY


func _bar(label: String) -> Dictionary:
	for item in _res.get("bars", []):
		var b: Dictionary = item
		if str(b.get("label", "")) == label:
			return b
	return {}


func _row_rect(index: int, label: String) -> Rect2:
	var b: Dictionary = _bar(label)
	var x0: float = _day_x(float(b.get("start", 0)))
	var x1: float = _day_x(float(b.get("end", 0)))
	return Rect2(x0, ROWS_TOP + float(index) * ROW_H + 6.0, maxf(6.0, x1 - x0), ROW_H - 12.0)


func _other(options: Array, current: String) -> String:
	for item in options:
		var o: Dictionary = item
		if str(o.get("id", "")) != current:
			return str(o.get("id", ""))
	return current


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _row_rect(2, "Licence").grow(6.0).has_point(mb.position):
				_dragging = true
				_drag_offset = mb.position.x - _day_x(float(_licence_start))
			elif _row_rect(0, "Build").grow(4.0).has_point(mb.position):
				_build_id = _other(_pz.get("build_options", []), _build_id)
				_emit()
			elif _row_rect(1, "Test").grow(4.0).has_point(mb.position):
				_test_id = _other(_pz.get("test_options", []), _test_id)
				_emit()
		else:
			_dragging = false
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _dragging:
			var step: float = float(_pz.get("licence_start_step", 5))
			var day: float = _x_day(mm.position.x - _drag_offset)
			day = clampf(round(day / step) * step, float(_pz.get("licence_start_min", 0)), float(_pz.get("licence_start_max", 90)))
			if int(day) != _licence_start:
				_licence_start = int(day)
				_emit()
		var hover: int = -1
		for i in range(3):
			if _row_rect(i, ["Build", "Test", "Licence"][i]).grow(4.0).has_point(mm.position):
				hover = i
		if hover != _hover_row:
			_hover_row = hover
			mouse_default_cursor_shape = Control.CURSOR_HSIZE if hover == 2 else (Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW)
			queue_redraw()


func _emit() -> void:
	GameState.play_sound("select")
	plan_changed.emit(_build_id, _test_id, _licence_start)


func _option(options: Array, id: String) -> Dictionary:
	for item in options:
		var o: Dictionary = item
		if str(o.get("id", "")) == id:
			return o
	return {}


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var w: float = size.x
	var launch_day: float = float(_pz.get("launch_day", 180))
	var finish: float = float(_res.get("finish_day", 0))
	# day grid
	var rows_bottom: float = ROWS_TOP + 4.0 * ROW_H
	for d in range(0, int(MAX_DAY) + 1, 30):
		var x: float = _day_x(float(d))
		draw_line(Vector2(x, ROWS_TOP - 6.0), Vector2(x, rows_bottom), Color(1, 1, 1, 0.08), 1.0)
		draw_string(font, Vector2(x - 12.0, ROWS_TOP - 12.0), "day %d" % d, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, UI.C_MUTED)
	# launch day line and rocket marker
	var lx: float = _day_x(launch_day)
	draw_line(Vector2(lx, ROWS_TOP - 30.0), Vector2(lx, rows_bottom + 6.0), UI.C_ACCENT, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lx, ROWS_TOP - 50.0), Vector2(lx - 7.0, ROWS_TOP - 34.0), Vector2(lx + 7.0, ROWS_TOP - 34.0)]), UI.C_ACCENT)
	draw_string(font, Vector2(lx + 10.0, ROWS_TOP - 36.0), "ROCKET LEAVES: DAY %d" % int(launch_day), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UI.C_ACCENT)
	# late zone
	if finish > launch_day:
		draw_rect(Rect2(lx, ROWS_TOP, _day_x(finish) - lx, 4.0 * ROW_H), Color(UI.C_RED, 0.14))
	# the four rows
	var labels: Array = ["Build", "Test", "Licence", "Ship"]
	var build: Dictionary = _option(_pz.get("build_options", []), _build_id)
	var test: Dictionary = _option(_pz.get("test_options", []), _test_id)
	var notes: Array = [
		"%s, click to switch" % str(build.get("label", "")),
		"%s, click to switch" % str(test.get("label", "")),
		"drag me",
		"",
	]
	for i in range(4):
		var name_text: String = str(labels[i])
		var y: float = ROWS_TOP + float(i) * ROW_H
		draw_string(font, Vector2(8.0, y + ROW_H * 0.5 + 5.0), name_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COLORS[name_text])
		var r: Rect2 = _row_rect(i, name_text)
		var c: Color = COLORS[name_text]
		var fill: Color = c.lightened(0.15) if i == _hover_row else c
		draw_rect(r, Color(fill, 0.85))
		draw_rect(r, c.lightened(0.4), false, 1.5)
		if i == 2:
			# grip lines on the draggable licence bar
			for g in range(3):
				var gx: float = r.position.x + 8.0 + float(g) * 5.0
				draw_line(Vector2(gx, r.position.y + 8.0), Vector2(gx, r.end.y - 8.0), Color(0, 0, 0, 0.45), 2.0)
		var b: Dictionary = _bar(name_text)
		var days: int = int(b.get("end", 0)) - int(b.get("start", 0))
		draw_string(font, Vector2(r.position.x + (22.0 if i == 2 else 8.0), r.position.y + r.size.y * 0.5 + 5.0), "%d days" % days, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10.0, 13, Color(0.02, 0.04, 0.08))
		# the surprise days, striped red at the end of the bar
		var extra: int = int(b.get("extra", 0))
		if extra > 0:
			var ex0: float = _day_x(float(int(b.get("end", 0)) - extra))
			var er: Rect2 = Rect2(ex0, r.position.y, r.end.x - ex0, r.size.y)
			draw_rect(er, Color(UI.C_RED, 0.75))
			var sx: float = er.position.x - er.size.y
			while sx < er.end.x:
				var a: Vector2 = Vector2(maxf(sx, er.position.x), er.end.y - maxf(0.0, er.position.x - sx))
				var bb: Vector2 = Vector2(minf(sx + er.size.y, er.end.x), er.position.y + maxf(0.0, sx + er.size.y - er.end.x))
				draw_line(a, bb, Color(0, 0, 0, 0.35), 2.0)
				sx += 8.0
			draw_string(font, Vector2(er.position.x + 3.0, er.position.y - 2.0), "+%d" % extra, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, UI.C_RED)
		if str(notes[i]) != "":
			draw_string(font, Vector2(r.end.x + 8.0, r.position.y + r.size.y * 0.5 + 5.0), str(notes[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UI.C_MUTED)
	# today, while the year plays
	if cursor_day >= 0.0:
		var cx: float = _day_x(cursor_day)
		draw_line(Vector2(cx, ROWS_TOP - 8.0), Vector2(cx, rows_bottom + 4.0), Color(1, 1, 1, 0.9), 2.0)
		draw_string(font, Vector2(cx + 4.0, rows_bottom + 2.0), "DAY %d" % int(cursor_day), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(1, 1, 1))
	# finish marker
	var fx: float = _day_x(finish)
	var fc: Color = UI.C_GREEN if finish <= launch_day else UI.C_RED
	draw_line(Vector2(fx, ROWS_TOP), Vector2(fx, rows_bottom), fc, 2.0)
	draw_string(font, Vector2(fx - 34.0, rows_bottom + 18.0), "READY DAY %d" % int(finish), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, fc)
	# money bar: what each step costs, and the team's pay for every day until shipping
	var my: float = rows_bottom + 48.0
	var bar_w: float = w - LEFT - 20.0
	var limit: float = float(_res.get("cost_limit_k", 1.0))
	var scale_max: float = maxf(limit * 1.25, float(_res.get("cost_k", 0.0)) * 1.05)
	draw_string(font, Vector2(8.0, my + 16.0), "MONEY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, UI.C_GREEN)
	draw_rect(Rect2(LEFT, my, bar_w, 24.0), Color(1, 1, 1, 0.06))
	var parts: Array = [
		["Build", float(build.get("cost_k", 0.0)), COLORS["Build"]],
		["Test", float(test.get("cost_k", 0.0)), COLORS["Test"]],
		["Licence", float(_pz.get("licence_cost_k", 0.0)), COLORS["Licence"]],
		["Ship", float(_pz.get("ship_cost_k", 0.0)), COLORS["Ship"]],
		["Team pay", float(_pz.get("staff_cost_k_per_day", 0.0)) * finish, Color(0.75, 0.55, 0.95)],
	]
	var x: float = LEFT
	for item in parts:
		var p: Array = item
		var pw: float = float(p[1]) / scale_max * bar_w
		draw_rect(Rect2(x, my, pw, 24.0), Color(p[2], 0.85))
		if pw > 54.0:
			draw_string(font, Vector2(x + 4.0, my + 16.0), "%s %s" % [str(p[0]), UI.money(float(p[1]))], HORIZONTAL_ALIGNMENT_LEFT, pw - 6.0, 11, Color(0.02, 0.04, 0.08))
		x += pw
	var limit_x: float = LEFT + limit / scale_max * bar_w
	draw_line(Vector2(limit_x, my - 8.0), Vector2(limit_x, my + 32.0), UI.C_YELLOW, 2.0)
	draw_string(font, Vector2(limit_x - 60.0, my + 46.0), "most you can spend: %s" % UI.money(limit), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, UI.C_YELLOW)
	var cost: float = float(_res.get("cost_k", 0.0))
	draw_string(font, Vector2(LEFT, my - 8.0), "Total %s" % UI.money(cost), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, UI.C_GREEN if cost <= limit + 0.001 else UI.C_RED)
