extends Control
## A popup used by the test lab and by ops. A full-screen dim layer blocks clicks
## behind it, with a centred panel: picture, title, body, one button per choice.
##
## Usage:
##   var card: Control = EventCard.new()
##   card.call("setup", event)
##   add_child(card)
##   card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
##   var index: int = await card.chosen
## The owner must stop its own clock while the card is open.

const UI = preload("res://scripts/ui/ui.gd")

signal chosen(index: int)

var _event: Dictionary = {}
var _done: bool = false


func setup(event: Dictionary) -> void:
	_event = event


func _ready() -> void:
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
	var panel: PanelContainer = UI.panel(UI.C_ORANGE, 20.0)
	panel.custom_minimum_size = Vector2(600.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(12)
	panel.add_child(col)
	var pic: Control = UI.picture(str(_event.get("picture", "")), Vector2(480.0, 270.0), str(_event.get("title", "")))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pic)
	col.add_child(UI.label(str(_event.get("title", "")), 24))
	var body: Label = UI.label(str(_event.get("body", "")), 15, UI.C_TEXT, true)
	body.custom_minimum_size = Vector2(560.0, 0.0)
	col.add_child(body)
	var choices: Array = _event.get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var text: String = str(choice.get("label", "")) + "\n" + str(choice.get("detail", ""))
		var b: Button = UI.button(text, _on_choice.bind(i), 560.0, i == 0)
		b.custom_minimum_size = Vector2(560.0, 60.0)
		col.add_child(b)


func _on_choice(index: int) -> void:
	if _done:
		return
	_done = true
	chosen.emit(index)
	queue_free()
