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


## One layout used by both the pictures and the drawing, so they always line up:
## the centre of each circle, and its radius.
const R: float = 34.0
const PIC: float = 50.0


func _centres() -> Array:
	var cy: float = 18.0 + R
	return [Vector2(70.0, cy), Vector2(size.x * 0.5, cy), Vector2(size.x - 70.0, cy)]


func _place_pics() -> void:
	var cs: Array = _centres()
	for i in range(_pics.size()):
		var pic: Control = _pics[i]
		pic.size = Vector2(PIC, PIC)
		pic.position = (cs[i] as Vector2) - Vector2(PIC, PIC) * 0.5


func set_flow(make: float, send: float, delivered: float, need: float) -> void:
	_make = make
	_send = send
	_delivered = delivered
	_need = maxf(1.0, need)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _text(font: Font, text: String, centre_x: float, y: float, fs: int, col: Color) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	draw_string(font, Vector2(centre_x - tw * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var cs: Array = _centres()
	var cy: float = (cs[0] as Vector2).y
	var nodes: Array = [["CAMERA", _make], ["RADIO", _send], ["GROUND", _delivered]]
	var bottleneck_is_radio: bool = _send < _make
	var short: bool = _delivered < _need
	# pipes between the circles, as thick as the data flowing through them
	for i in range(2):
		var x0: float = (cs[i] as Vector2).x + R + 6.0
		var x1: float = (cs[i + 1] as Vector2).x - R - 6.0
		var rate: float = _make if i == 0 else _delivered
		var thick: float = clampf(rate / FULL_MB_WK * 30.0, 3.0, 30.0)
		var c: Color = UI.C_ACCENT
		if i == 1 and bottleneck_is_radio and short:
			c = UI.C_RED
		elif i == 1 and not short:
			c = UI.C_GREEN
		draw_rect(Rect2(x0, cy - thick * 0.5, x1 - x0, thick), Color(c, 0.35))
		draw_rect(Rect2(x0, cy - thick * 0.5, x1 - x0, thick), Color(c, 0.9), false, 1.5)
		var gap: float = 26.0
		var x: float = x0 + fmod(_t * 60.0, gap)
		while x < x1:
			draw_circle(Vector2(x, cy), minf(4.0, thick * 0.3), Color(1, 1, 1, 0.8))
			x += gap
		_text(font, "%d MB/wk" % int(round(rate)), (x0 + x1) * 0.5, cy - 22.0, 14, c)
	# a ring behind each picture, and its caption centred under it
	for i in range(3):
		var n: Array = nodes[i]
		var cc: Vector2 = cs[i]
		var edge: Color = UI.C_ACCENT
		if i == 1 and bottleneck_is_radio and short:
			edge = UI.C_RED
		if i == 2:
			edge = UI.C_GREEN if not short else UI.C_ORANGE
		draw_circle(cc, R + 5.0, Color(edge, 0.10))
		draw_circle(cc, R, Color(0.02, 0.05, 0.12, 0.9))
		draw_arc(cc, R, 0.0, TAU, 48, edge, 2.5)
		var caption: String = "%s  %d" % [str(n[0]), int(round(float(n[1])))]
		if i == 2:
			caption = "GROUND  %d of %d" % [int(round(_delivered)), int(round(_need))]
		_text(font, caption, cc.x, cc.y + R + 20.0, 14, edge)
	# what is wrong, above the step that causes it
	if not short:
		_text(font, "GOAL MET", (cs[2] as Vector2).x, 12.0, 13, UI.C_GREEN)
	elif bottleneck_is_radio:
		_text(font, "BOTTLENECK", (cs[1] as Vector2).x, 12.0, 13, UI.C_RED)
	else:
		_text(font, "TOO LITTLE DATA MADE", (cs[0] as Vector2).x + 40.0, 12.0, 13, UI.C_RED)
