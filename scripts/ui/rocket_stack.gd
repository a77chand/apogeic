extends Control
## A rocket drawn in code with its payload bay cut open, so the player can see what they
## loaded. Each chosen part is a block in the bay; the taller the block, the heavier the
## part. The bay's top line is the mass limit: blocks that go past it turn red.
##   rocket.call("set_load", [{"name": "Camera", "mass": 0.7, "category": "instrument"}, ...], 1.3, 3.6)

const UI = preload("res://scripts/ui/ui.gd")

const CATEGORY_COLORS: Dictionary = {
	"bus": Color(0.55, 0.60, 0.70),
	"solar": Color(0.30, 0.55, 0.95),
	"battery": Color(0.25, 0.75, 0.55),
	"instrument": Color(0.95, 0.70, 0.25),
	"radio": Color(0.36, 0.86, 0.95),
	"extra": Color(0.75, 0.55, 0.95),
}

var _items: Array = []
var _bus_kg: float = 0.0
var _limit_kg: float = 1.0
var _shake: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 420)


func set_load(items: Array, bus_kg: float, limit_kg: float) -> void:
	_items = items
	_bus_kg = bus_kg
	_limit_kg = maxf(0.1, limit_kg)
	var total: float = bus_kg
	for item in items:
		total += float((item as Dictionary).get("mass", 0.0))
	_shake = 1.0 if total > _limit_kg + 0.0001 else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _shake > 0.0:
		queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var cx: float = w * 0.5
	var wobble: float = 0.0
	if _shake > 0.0:
		wobble = sin(Time.get_ticks_msec() * 0.03) * 1.5
	var body_w: float = 92.0
	var left: float = cx - body_w * 0.5 + wobble
	var bay_top: float = 70.0
	var bay_bottom: float = 290.0
	var bay_h: float = bay_bottom - bay_top
	var hull: Color = Color(0.86, 0.89, 0.94)
	var edge: Color = Color(0.03, 0.07, 0.14)
	# nose cone (fairing top)
	var nose: PackedVector2Array = PackedVector2Array([Vector2(left, bay_top), Vector2(cx + wobble, 6.0), Vector2(left + body_w, bay_top)])
	draw_colored_polygon(nose, hull)
	draw_polyline(PackedVector2Array([nose[0], nose[1], nose[2]]), edge, 2.0)
	# lower body, fins and engine
	draw_rect(Rect2(left, bay_bottom, body_w, 80.0), hull)
	draw_rect(Rect2(left, bay_bottom + 20.0, body_w, 10.0), Color(0.85, 0.30, 0.30))
	draw_colored_polygon(PackedVector2Array([Vector2(left, bay_bottom + 40.0), Vector2(left - 26.0, bay_bottom + 92.0), Vector2(left, bay_bottom + 80.0)]), Color(0.70, 0.74, 0.82))
	draw_colored_polygon(PackedVector2Array([Vector2(left + body_w, bay_bottom + 40.0), Vector2(left + body_w + 26.0, bay_bottom + 92.0), Vector2(left + body_w, bay_bottom + 80.0)]), Color(0.70, 0.74, 0.82))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 20.0 + wobble, bay_bottom + 80.0), Vector2(cx + 20.0 + wobble, bay_bottom + 80.0), Vector2(cx + 28.0 + wobble, bay_bottom + 104.0), Vector2(cx - 28.0 + wobble, bay_bottom + 104.0)]), Color(0.35, 0.38, 0.45))
	# the open payload bay
	draw_rect(Rect2(left, bay_top, body_w, bay_h), Color(0.04, 0.08, 0.16))
	draw_rect(Rect2(left, bay_top, body_w, bay_h), edge, false, 2.0)
	# blocks, stacked from the bottom: the bus first, then each part
	var px_per_kg: float = bay_h / _limit_kg
	var y: float = bay_bottom
	var font: Font = ThemeDB.fallback_font
	var stack: Array = [{"name": "Satellite body", "mass": _bus_kg, "category": "bus"}]
	stack.append_array(_items)
	for item in stack:
		var it: Dictionary = item
		var h: float = float(it.get("mass", 0.0)) * px_per_kg
		var top: float = y - h
		var over: bool = top < bay_top - 0.5
		var c: Color = CATEGORY_COLORS.get(str(it.get("category", "")), Color(0.6, 0.6, 0.6))
		if over:
			c = UI.C_RED
		draw_rect(Rect2(left + 6.0, top + 1.0, body_w - 12.0, maxf(1.0, h - 2.0)), c)
		if h >= 13.0:
			var text: String = "%s %.2f kg" % [str(it.get("name", "")), float(it.get("mass", 0.0))]
			if str(it.get("category", "")) == "bus":
				text = "Body %.1f kg" % float(it.get("mass", 0.0))
			draw_string(font, Vector2(left + 9.0, top + minf(h * 0.5 + 5.0, h - 2.0)), text, HORIZONTAL_ALIGNMENT_LEFT, body_w - 18.0, 10, Color(0.02, 0.04, 0.08))
		y = top
	# the limit line
	draw_dashed_line(Vector2(left - 14.0, bay_top), Vector2(left + body_w + 14.0, bay_top), Color(UI.C_YELLOW, 0.95), 2.0, 6.0)
	draw_string(font, Vector2(left - 14.0, bay_top - 6.0), "limit %.1f kg" % _limit_kg, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, UI.C_YELLOW)
	if _shake > 0.0:
		draw_string(font, Vector2(left - 10.0, bay_bottom + 128.0), "TOO HEAVY TO LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, UI.C_RED)
