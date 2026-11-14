
extends Control

var _bars: Array = []
var _launch_day: int = 180

func _ready() -> void:
	custom_minimum_size = Vector2(720.0, 260.0)
	queue_redraw()


func set_data(bars: Array, launch_day: int) -> void:
	_bars = bars
	_launch_day = launch_day
	queue_redraw()


func _draw() -> void:
	var chart_width: float = size.x
	var chart_height: float = size.y

	# Chart background
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.055, 0.075, 0.12)
	)

	var left_margin: float = 125.0
	var right_margin: float = 20.0
	var top_margin: float = 25.0
	var bottom_margin: float = 25.0

	var usable_width: float = chart_width - left_margin - right_margin
	var usable_height: float = chart_height - top_margin - bottom_margin

	# Day-axis guide lines
	var font: Font = ThemeDB.fallback_font

	for day in range(0, 221, 20):
		var x: float = left_margin + (float(day) / 220.0) * usable_width

		draw_line(
			Vector2(x, top_margin),
			Vector2(x, chart_height - bottom_margin),
			Color(0.22, 0.27, 0.34),
			1.0
		)

		draw_string(
			font,
			Vector2(x - 12.0, chart_height - 5.0),
			str(day),
			HORIZONTAL_ALIGNMENT_CENTER,
			30.0,
			11,
			Color(0.65, 0.7, 0.78)
		)

	if _bars.is_empty():
		draw_string(
			font,
			Vector2(left_margin, chart_height / 2.0),
			"Schedule will appear here",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.65, 0.7, 0.78)
		)
		return

	var row_height: float = usable_height / float(_bars.size())

	for i in range(_bars.size()):
		var bar: Dictionary = _bars[i]

		var label: String = str(bar.get("label", "Stage"))
		var start_day: float = float(bar.get("start", 0.0))
		var end_day: float = float(bar.get("end", 0.0))

		var y: float = top_margin + (float(i) + 0.5) * row_height

		draw_string(
			font,
			Vector2(8.0, y + 5.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			left_margin - 15.0,
			11,
			Color(0.85, 0.88, 0.93)
		)

		var start_x: float = left_margin + (start_day / 220.0) * usable_width
		var end_x: float = left_margin + (end_day / 220.0) * usable_width

		var bar_rect: Rect2 = Rect2(
			start_x,
			y - 7.0,
			maxf(end_x - start_x, 2.0),
			14.0
		)

		draw_rect(bar_rect, Color(0.12, 0.65, 0.78))

	# Launch-day marker
	var launch_x: float = left_margin + (float(_launch_day) / 220.0) * usable_width

	var marker_y: float = top_margin
	while marker_y < chart_height - bottom_margin:
		draw_line(
			Vector2(launch_x, marker_y),
			Vector2(launch_x, minf(marker_y + 7.0, chart_height - bottom_margin)),
			Color(1.0, 0.25, 0.25),
			2.0
		)
		marker_y += 12.0

	draw_string(
		font,
		Vector2(launch_x + 5.0, top_margin - 7.0),
		"Launch",
		HORIZONTAL_ALIGNMENT_LEFT,
		55.0,
		11,
		Color(1.0, 0.4, 0.4)
	)
