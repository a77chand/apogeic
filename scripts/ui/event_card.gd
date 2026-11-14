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

const DEFAULT_SECONDS: float = 15.0

var timed_out: bool = false   # true when the choice was made by the timer running out
var _event: Dictionary = {}
var _done: bool = false
var _total: float = DEFAULT_SECONDS
var _left: float = DEFAULT_SECONDS
var _default_index: int = 0
var _bar: ProgressBar = null
var _timer_label: Label = null


func setup(event: Dictionary) -> void:
	_event = event
	_total = float(event.get("seconds", DEFAULT_SECONDS))
	_left = _total
	var choices: Array = event.get("choices", [])
	_default_index = clampi(int(event.get("timeout_choice", choices.size() - 1)), 0, maxi(0, choices.size() - 1))


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
	var pic: Control = UI.picture(str(_event.get("picture", "")), Vector2(384.0, 216.0), str(_event.get("title", "")))
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pic)
	col.add_child(UI.label(str(_event.get("title", "")), 24))
	var body: Label = UI.label(str(_event.get("body", "")), 15, UI.C_TEXT, true)
	body.custom_minimum_size = Vector2(560.0, 0.0)
	col.add_child(body)
	var choices: Array = _event.get("choices", [])
	var fuel_now: float = float(GameState.ops.get("fuel_pct", 100.0))
	if str(choices).contains("fuel"):
		col.add_child(UI.label("Fuel left: %d%%" % int(round(fuel_now)), 16, UI.C_YELLOW))
	var fitted: Array = GameState.launch_eval.get("part_ids", [])
	if fitted.is_empty():
		fitted = GameState.evaluate().get("part_ids", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var text: String = str(choice.get("label", "")) + "\n" + str(choice.get("detail", ""))
		var needs: String = str(choice.get("requires_part", ""))
		var missing: bool = needs != "" and not fitted.has(needs)
		var needs_fuel: float = float(choice.get("requires_fuel", 0.0))
		var no_fuel: bool = needs_fuel > 0.0 and fuel_now < needs_fuel
		if missing:
			var part: Dictionary = GameState.parts.get(needs, {})
			text = str(choice.get("label", "")) + "\nNot possible: you did not fit the " + str(part.get("name", needs)) + "."
		if no_fuel:
			text = str(choice.get("label", "")) + "\nNot enough fuel: it needs %d%% and only %d%% is left." % [int(round(needs_fuel)), int(round(fuel_now))]
		var b: Button = UI.button(text, _on_choice.bind(i), 560.0, i == 0 and not missing and not no_fuel)
		b.custom_minimum_size = Vector2(560.0, 56.0)
		b.disabled = missing or no_fuel
		col.add_child(b)
	# the countdown
	_bar = UI.meter(560.0)
	col.add_child(_bar)
	_timer_label = UI.label("", 14, UI.C_MUTED, true)
	_timer_label.custom_minimum_size = Vector2(560.0, 0.0)
	col.add_child(_timer_label)
	_update_timer()


func _process(delta: float) -> void:
	if _done:
		return
	_left -= delta
	if _left <= 0.0:
		_left = 0.0
		_update_timer()
		timed_out = true
		_on_choice(_default_index)
		return
	_update_timer()


func _update_timer() -> void:
	if _bar == null:
		return
	var fraction: float = _left / maxf(0.001, _total)
	var status: String = "green"
	if _left <= 5.0:
		status = "red"
	elif fraction <= 0.5:
		status = "yellow"
	UI.set_meter(_bar, fraction * 100.0, status)
	var choices: Array = _event.get("choices", [])
	var fallback: String = ""
	if _default_index < choices.size():
		var c: Dictionary = choices[_default_index]
		fallback = str(c.get("label", ""))
	_timer_label.text = "Decide in %d seconds. If time runs out: %s." % [int(ceil(_left)), fallback]


func _on_choice(index: int) -> void:
	if _done:
		return
	_done = true
	chosen.emit(index)
	queue_free()
