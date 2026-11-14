extends Control
## Half of the tilted orbit ellipse. The orbit is drawn as two of these: the BACK half goes
## behind the Earth (faint) and the FRONT half goes in front of it (bright), which is what
## makes the satellite look like it circles the planet instead of sliding across it.
## The front half also draws the data pulse (rings and a dashed link to the ground station).

var centre: Vector2 = Vector2.ZERO
var radius_a: float = 250.0
var radius_b: float = 90.0
var tilt: float = 0.0
var front: bool = false
var pulse_left: float = 0.0
var sat_pos: Vector2 = Vector2.ZERO
var ground_pos: Vector2 = Vector2.ZERO

const SEGMENTS: int = 72
const CYAN: Color = Color(0.247, 0.816, 0.878)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func point_at(theta: float) -> Vector2:
	return centre + Vector2(cos(theta) * radius_a, sin(theta) * radius_b).rotated(tilt)


func _draw() -> void:
	for i in range(SEGMENTS):
		if i % 2 == 1:
			continue   # dashes
		var a0: float = TAU * float(i) / float(SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(SEGMENTS)
		if (sin((a0 + a1) / 2.0) > 0.0) != front:
			continue   # the other half belongs to the other overlay
		if front:
			draw_line(point_at(a0), point_at(a1), CYAN, 2.5)
		else:
			draw_line(point_at(a0), point_at(a1), Color(CYAN, 0.30), 1.5)
	if front and pulse_left > 0.0:
		for i in range(3):
			var ring: float = (1.0 - pulse_left) * 70.0 + float(i) * 16.0
			draw_arc(sat_pos, ring, 0.0, TAU, 32, Color(CYAN, pulse_left * 0.7), 2.0)
		draw_dashed_line(sat_pos, ground_pos, Color(CYAN, pulse_left * 0.8), 2.0, 8.0)
