extends Control
## An "Are you sure?" box with Yes and No. Covers the screen until one is pressed.
##   Confirm.ask(self, "Reset progress?", "This clears every puzzle and mission.", "Yes, reset", _do_reset)

const UI = preload("res://scripts/ui/ui.gd")
const Self = preload("res://scripts/ui/confirm.gd")

var _title: String = ""
var _body: String = ""
var _yes_text: String = "Yes"
var _on_yes: Callable = Callable()


static func ask(host: Node, title: String, body: String, yes_text: String, on_yes: Callable) -> Control:
	var box: Control = Self.new()
	box.call("setup", title, body, yes_text, on_yes)
	host.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return box


func setup(title: String, body: String, yes_text: String, on_yes: Callable) -> void:
	_title = title
	_body = body
	_yes_text = yes_text
	_on_yes = on_yes


func _ready() -> void:
	z_index = 100   # always above the screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# everything centred: title, text and the two buttons
	var panel: PanelContainer = UI.neon_panel(UI.C_ORANGE, 26.0)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var title: Label = UI.label(_title, 24, UI.C_ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body: Label = UI.label(_body, 16, UI.C_TEXT, true)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(468.0, 0.0)
	col.add_child(body)
	var row: HBoxContainer = UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UI.button("No", _on_no, 160.0, false))
	row.add_child(UI.button(_yes_text, _on_yes_pressed, 200.0, true))


func _on_no() -> void:
	queue_free()


func _on_yes_pressed() -> void:
	var cb: Callable = _on_yes
	queue_free()
	if cb.is_valid():
		cb.call()
