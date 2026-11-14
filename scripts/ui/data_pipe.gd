extends Control
## The data pipeline for Puzzle 3, drawn in code: camera, then radio, then the ground.
## Each pipe is as thick as the data flowing through it, and the narrowest one (the
## bottleneck) is drawn red, so the player can see where the photos get stuck.
##   pipe.call("set_flow", make, send, delivered, need)

const UI = preload("res://scripts/ui/ui.gd")

var _make: float = 0.0
var _send: float = 0.0
var _delivered: float = 0.0
var _need: float = 1.0
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_flow(make: float, send: float, delivered: float, need: float) -> void:
	_make = make
	_send = send
	_delivered = delivered
	_need = maxf(1.0, need)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var mid: float = size.y * 0.5 + 6.0
	var font: Font = ThemeDB.fallback_font
	var nodes: Array = [["CAMERA", "makes", _make], ["RADIO", "sends", _send], ["GROUND", "gets", _delivered]]
	var xs: Array = [70.0, w * 0.5, w - 70.0]
	var top: float = maxf(_make, maxf(_send, 1.0))
	var bottleneck_is_radio: bool = _send < _make
	# pipes between the boxes
	for i in range(2):
		var x0: float = float(xs[i]) + 56.0
		var x1: float = float(xs[i + 1]) - 56.0
		var rate: float = _make if i == 0 else _delivered
		var thick: float = clampf(rate / top * 34.0, 3.0, 34.0)
		var c: Color = UI.C_ACCENT
		if i == 1 and bottleneck_is_radio and _delivered < _need:
			c = UI.C_RED
		elif i == 1 and _delivered >= _need:
			c = UI.C_GREEN
		draw_rect(Rect2(x0, mid - thick * 0.5, x1 - x0, thick), Color(c, 0.35))
		draw_rect(Rect2(x0, mid - thick * 0.5, x1 - x0, thick), Color(c, 0.9), false, 1.5)
		# moving dots: the data flowing
		var gap: float = 26.0
		var shift: float = fmod(_t * 60.0, gap)
		var x: float = x0 + shift
		while x < x1:
			draw_circle(Vector2(x, mid), minf(4.0, thick * 0.3), Color(1, 1, 1, 0.8))
			x += gap
		draw_string(font, Vector2((x0 + x1) * 0.5 - 40.0, mid - 24.0), "%d MB/wk" % int(round(rate)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, c)
	# the boxes
	for i in range(3):
		var n: Array = nodes[i]
		var cx: float = float(xs[i])
		var r: Rect2 = Rect2(cx - 56.0, mid - 34.0, 112.0, 68.0)
		var edge: Color = UI.C_ACCENT
		if i == 1 and bottleneck_is_radio and _delivered < _need:
			edge = UI.C_RED
		if i == 2:
			edge = UI.C_GREEN if _delivered >= _need else UI.C_ORANGE
		draw_rect(r, Color(0.03, 0.08, 0.17, 0.95))
		draw_rect(r, edge, false, 2.0)
		draw_string(font, Vector2(r.position.x + 10.0, r.position.y + 22.0), str(n[0]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, edge)
		draw_string(font, Vector2(r.position.x + 10.0, r.position.y + 48.0), "%s %d" % [str(n[1]), int(round(float(n[2])))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, UI.C_TEXT)
	# the label over the narrowest step
	var label_x: float = float(xs[1]) - 44.0
	if _delivered >= _need:
		draw_string(font, Vector2(float(xs[2]) - 70.0, mid - 46.0), "GOAL MET (%d)" % int(round(_need)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, UI.C_GREEN)
	elif bottleneck_is_radio:
		draw_string(font, Vector2(label_x, mid - 46.0), "BOTTLENECK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, UI.C_RED)
	else:
		draw_string(font, Vector2(float(xs[0]) - 50.0, mid - 46.0), "TOO LITTLE DATA MADE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, UI.C_RED)
	draw_string(font, Vector2(float(xs[2]) - 56.0, mid + 54.0), "needs %d MB/wk" % int(round(_need)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UI.C_MUTED)
