## A small up/down triangle drawn with code, so it doesn't depend on the font
## having arrow characters (the web build has no system fonts to fall back on).
extends Control

const GOOD_COLOR := Color(0.35, 0.85, 0.45)
const BAD_COLOR := Color(0.95, 0.35, 0.3)
const FLAT_COLOR := Color(0.6, 0.6, 0.6)

var direction := 0  # 1 = up, -1 = down, 0 = no change
var is_good := true


## `high_is_bad` is true for radiation, where going up is bad news.
func set_trend(delta: float, high_is_bad: bool) -> void:
	direction = 0
	if delta > 0.05:
		direction = 1
	elif delta < -0.05:
		direction = -1
	is_good = (direction > 0) != high_is_bad
	queue_redraw()  # ask Godot to call _draw() again


func _draw() -> void:
	var w := size.x
	var h := size.y
	if direction == 0:
		draw_line(Vector2(w * 0.2, h * 0.5), Vector2(w * 0.8, h * 0.5), FLAT_COLOR, 2.0)
		return
	var points: PackedVector2Array
	if direction > 0:
		points = PackedVector2Array([Vector2(w * 0.5, h * 0.2), Vector2(w * 0.85, h * 0.8), Vector2(w * 0.15, h * 0.8)])
	else:
		points = PackedVector2Array([Vector2(w * 0.15, h * 0.2), Vector2(w * 0.85, h * 0.2), Vector2(w * 0.5, h * 0.8)])
	draw_colored_polygon(points, GOOD_COLOR if is_good else BAD_COLOR)
