extends PanelContainer
## A part shown as a card: icon, name, one line of numbers.
## Click it to fit the part (works everywhere). It can also be dragged onto a drop zone.
## Usage:  var card = PartCard.new(); card.setup(part); parent.add_child(card)

const UI = preload("res://scripts/ui/ui.gd")

signal clicked(part_id: String)
signal hovered(part_id: String)
signal unhovered

var part_id: String = ""
var _icon_path: String = ""
var _fitted: bool = false
var _hover: bool = false


func setup(part: Dictionary) -> void:
	part_id = str(part.get("id", ""))
	_icon_path = str(part.get("icon", ""))
	custom_minimum_size = Vector2(150.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = str(part.get("blurb", ""))
	var col: VBoxContainer = UI.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var pic: Control = UI.picture(_icon_path, Vector2(64.0, 64.0), str(part.get("name", "")))
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pic)
	var name_label: Label = UI.label(str(part.get("name", "")), 13, UI.C_TEXT, true)
	name_label.custom_minimum_size = Vector2(130.0, 0.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	var nums: Label = UI.label(_numbers_line(part), 11, UI.C_MUTED, true)
	nums.custom_minimum_size = Vector2(130.0, 0.0)
	nums.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nums)
	_restyle()


## Marks the card as already fitted on the satellite (shows a cyan border).
func set_fitted(value: bool) -> void:
	_fitted = value
	_restyle()


func _numbers_line(part: Dictionary) -> String:
	var bits: Array = []
	bits.append("%.2f kg" % float(part.get("mass_kg", 0.0)))
	var gen: float = float(part.get("power_gen_w", 0.0))
	var use: float = float(part.get("power_use_w", 0.0))
	var wh: float = float(part.get("battery_wh", 0.0))
	var make: float = float(part.get("make_mb_wk", 0.0))
	var send: float = float(part.get("send_mb_wk", 0.0))
	if gen > 0.0:
		bits.append("+%d W" % int(gen))
	if use > 0.0:
		bits.append("-%d W" % int(use))
	if wh > 0.0:
		bits.append("%d Wh" % int(wh))
	if make > 0.0:
		bits.append("makes %d MB/wk" % int(make))
	if send > 0.0:
		bits.append("sends +%d MB/wk" % int(send))
	bits.append(UI.money(float(part.get("cost_k", 0.0))))
	return " | ".join(PackedStringArray(bits))


func _restyle() -> void:
	var border: Color = UI.C_BORDER
	var fill: Color = UI.C_DEEP
	if _fitted:
		border = UI.C_CYAN
	if _hover:
		fill = UI.C_HOVER
	add_theme_stylebox_override("panel", UI.box(fill, border, 12, 2, 8.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		_restyle()
		hovered.emit(part_id)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_restyle()
		unhovered.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Fire on release, so starting a drag does not also count as a click.
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			GameState.play_sound("select")
			clicked.emit(part_id)


func _get_drag_data(_at_position: Vector2) -> Variant:
	set_drag_preview(UI.picture(_icon_path, Vector2(48.0, 48.0), part_id))
	return {"type": "part", "id": part_id}
