extends Control
## The data pipeline for Puzzle 3: pictures of the camera, the radio and the ground station,
## joined by pipes drawn in code.
## Each pipe is as thick as the data flowing through it, and the narrowest one (the
## bottleneck) is drawn red, so the player can see where the photos get stuck.
##   pipe.call("set_flow", make, send, delivered, need)

const UI = preload("res://scripts/ui/ui.gd")
## Fixed scale for pipe thickness, so changing the camera only changes the camera's pipe
## (it used to scale to the biggest flow, which made the radio pipe grow when the camera shrank).
const FULL_MB_WK: float = 80.0

var _make: float = 0.0
var _send: float = 0.0
var _delivered: float = 0.0
var _need: float = 1.0
var _t: float = 0.0


const PICTURES: Array = ["res://art/icons/part_camera.png", "res://art/modules/part_antenna_small.png", "res://art/modules/ground_station.png"]

var _pics: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The camera, the radio and the ground station as pictures (not text boxes).
func _ready() -> void:
	for path in PICTURES:
		var pic: Control = UI.picture(str(path), Vector2(62, 62))
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		_pics.append(pic)
	resized.connect(_place_pics)
	_place_pics()


func _place_pics() -> void:
	var xs: Array = [70.0, size.x * 0.5, size.x - 70.0]
	for i in range(_pics.size()):
		var pic: Control = _pics[i]
		pic.size = Vector2(62, 62)
		pic.position = Vector2(float(xs[i]) - 31.0, size.y * 0.5 + 6.0 - 41.0)


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
	var bottleneck_is_radio: bool = _send < _make
	# pipes between the boxes
	for i in range(2):
		var x0: float = float(xs[i]) + 44.0
		var x1: float = float(xs[i + 1]) - 44.0
		var rate: float = _make if i == 0 else _delivered
		var thick: float = clampf(rate / FULL_MB_WK * 34.0, 3.0, 34.0)
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
	# a glow under each picture (red at the bottleneck, green or orange at the ground),
	# and a short caption under it
	for i in range(3):
		var n: Array = nodes[i]
		var cx: float = float(xs[i])
		var edge: Color = UI.C_ACCENT
		if i == 1 and bottleneck_is_radio and _delivered < _need:
			edge = UI.C_RED
		if i == 2:
			edge = UI.C_GREEN if _delivered >= _need else UI.C_ORANGE
		var c: Vector2 = Vector2(cx, mid - 4.0)
		draw_circle(c, 40.0, Color(0.02, 0.05, 0.12, 0.85))
		draw_arc(c, 40.0, 0.0, TAU, 48, edge, 2.5)
		draw_circle(c, 45.0, Color(edge, 0.10))
		var caption: String = "%s  %d" % [str(n[0]), int(round(float(n[2])))]
		var tw: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
		draw_string(font, Vector2(cx - tw * 0.5, mid + 48.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, edge)
	# the label over the narrowest step
	var label_x: float = float(xs[1]) - 44.0
	mid -= 6.0
	if _delivered >= _need:
		draw_string(font, Vector2(float(xs[2]) - 70.0, mid - 54.0), "GOAL MET (%d)" % int(round(_need)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, UI.C_GREEN)
	elif bottleneck_is_radio:
		draw_string(font, Vector2(label_x, mid - 54.0), "BOTTLENECK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, UI.C_RED)
	else:
		draw_string(font, Vector2(float(xs[0]) - 50.0, mid - 54.0), "TOO LITTLE DATA MADE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, UI.C_RED)
	draw_string(font, Vector2(float(xs[2]) - 46.0, mid + 62.0), "needs %d" % int(round(_need)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UI.C_MUTED)
