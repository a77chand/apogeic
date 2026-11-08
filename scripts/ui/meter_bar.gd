## One meter in the HUD: icon, name, bar, value, change since last sol, trend arrow.
## The meter_panel scene has six of these; set `meter_id` etc. in the Inspector.
extends HBoxContainer

const Art = preload("res://scripts/ui/art.gd")
const DANGER_COLOR := Color(0.95, 0.35, 0.3)

@export var meter_id := "power"
@export var label_text := "Power"
@export var bar_color := Color(0.95, 0.8, 0.25)
## True for radiation: a full bar is dangerous instead of good.
@export var high_is_bad := false

# $Name is shorthand for get_node("Name"). @onready waits until the node exists.
@onready var swatch: ColorRect = $Swatch
@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $Name
@onready var bar: ProgressBar = $Bar
@onready var value_label: Label = $Value
@onready var delta_label: Label = $Delta
@onready var trend: Control = $Trend


func _ready() -> void:
	name_label.text = label_text
	# Color the bar's filled part. StyleBoxFlat is a plain colored rectangle.
	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", fill)
	var empty := StyleBoxFlat.new()  # the empty part of the bar
	empty.bg_color = Color(0.22, 0.24, 0.29)
	bar.add_theme_stylebox_override("background", empty)
	swatch.color = bar_color
	# Use the icon PNG if an artist has added one, otherwise a colored square.
	var tex := Art.icon_texture(meter_id)
	if tex != null:
		icon.texture = tex
		swatch.hide()
	else:
		icon.hide()


func show_value(value: float, max_value: float, delta: float) -> void:
	bar.max_value = max_value
	bar.value = value
	value_label.text = "%d / %d" % [roundi(value), roundi(max_value)]
	# Show the change since last sol, like "+6" or "-4" (blank if nothing changed).
	if absf(delta) < 0.5:
		delta_label.text = ""
	elif delta > 0:
		delta_label.text = "+%d" % roundi(delta)
	else:
		delta_label.text = "%d" % roundi(delta)
	trend.set_trend(delta, high_is_bad)
	# Turn the number red when the meter is in the danger zone.
	var fraction := value / max_value if max_value > 0.0 else 0.0
	var danger := fraction > 0.7 if high_is_bad else fraction < 0.2
	if danger:
		value_label.add_theme_color_override("font_color", DANGER_COLOR)
	else:
		value_label.remove_theme_color_override("font_color")
