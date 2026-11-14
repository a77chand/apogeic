
extends Control

const UI = preload("res://scripts/ui/ui.gd")

var points: Array = []
var eclipse_min: float = 0.0
var period_min: float = 100.0
var min_level: float = 20.0


func set_data(new_points: Array, new_eclipse_min: float, new_period_min: float, new_min_level: float) -> void:
	points = new_points
	eclipse_min = new_eclipse_min
	period_min = new_period_min
	min_level = new_min_level
	queue_redraw()


func _draw() -> void:
	var chart_size: Vector2 = size

	if chart_size.x <= 0.0 or chart_size.y <= 0.0:
		return

	var margin_left: float = 45.0
	var margin_right: float = 15.0
	var margin_top: float = 20.0
	var margin_bottom: float = 35.0

	var graph_width: float = chart_size.x - margin_left - margin_right
	var graph_height: float = chart_size.y - margin_top - margin_bottom

	var graph_rect: Rect2 = Rect2(
		margin_left,
		margin_top,
		graph_width,
		graph_height
	)

	draw_rect(Rect2(Vector2.ZERO, chart_size), UI.C_DEEP)

	# Draw the eclipse region.
	var eclipse_width: float = graph_width * eclipse_min / period_min
	var eclipse_rect: Rect2 = Rect2(
		Vector2(margin_left, margin_top),
		Vector2(eclipse_width, graph_height)
	)
	draw_rect(eclipse_rect, Color(0.35, 0.35, 0.55, 0.35))

	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_left + 5.0, margin_top + 15.0),
		"Eclipse",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		UI.C_MUTED
	)

	# Draw the minimum battery level line.
	var threshold_y: float = margin_top + graph_height * (1.0 - min_level / 100.0)

	draw_line(
		Vector2(margin_left, threshold_y),
		Vector2(margin_left + graph_width, threshold_y),
		UI.C_RED,
		2.0
	)

	# Draw the battery level line.
	for i in range(points.size() - 1):
		var point_a: Array = points[i]
		var point_b: Array = points[i + 1]

		var x1: float = margin_left + graph_width * float(point_a[0]) / period_min
		var y1: float = margin_top + graph_height * (1.0 - float(point_a[1]) / 100.0)

		var x2: float = margin_left + graph_width * float(point_b[0]) / period_min
		var y2: float = margin_top + graph_height * (1.0 - float(point_b[1]) / 100.0)

		draw_line(
			Vector2(x1, y1),
			Vector2(x2, y2),
			UI.C_CYAN,
			3.0
		)

	# Draw graph labels.
	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_left, chart_size.y - 8.0),
		"0 min",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		UI.C_MUTED
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(margin_left + graph_width - 45.0, chart_size.y - 8.0),
		str(int(period_min)) + " min",
		HORIZONTAL_ALIGNMENT_RIGHT,
		-1,
		11,
		UI.C_MUTED
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(5.0, margin_top + 5.0),
		"100%",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		UI.C_MUTED
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(5.0, margin_top + graph_height),
		"0%",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		UI.C_MUTED
	)
