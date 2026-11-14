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
##
## No choice is highlighted and the order is shuffled, so the safe answer is never just
## "the first button". The player can ask for a free clue, or pay for an expert's advice
## (advice_paid_k tells the owner what to charge). If the timer runs out, the card shows
## what was chosen for them and the penalty, before closing.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")

signal chosen(index: int)

const DEFAULT_SECONDS: float = 22.0   # 20-25 s to decide
const ADVICE_COST_K: float = 15.0
const TIMEOUT_NOTICE_SECONDS: float = 7.0

var timed_out: bool = false   # true when the choice was made by the timer running out
var _event: Dictionary = {}
var _done: bool = false
var _total: float = DEFAULT_SECONDS
var _left: float = DEFAULT_SECONDS
var _default_index: int = 0
var _bar: ProgressBar = null
var _timer_label: Label = null
var advice_paid_k: float = 0.0   # money spent on expert advice; the owner charges it
var _col: VBoxContainer = null
var _choice_buttons: Array = []
var _help_label: Label = null
var _clue_btn: Button = null
var _advice_btn: Button = null
var _notice_left: float = -1.0
var _picked: int = -1


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
	_col = col
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
	# a fixed shuffle per event, so the order does not give the answer away
	var order: Array = range(choices.size())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(_event.get("id", "")))
	for k in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var tmp: int = order[k]
		order[k] = order[j]
		order[j] = tmp
	for i in order:
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
		var b: Button = UI.button(text, _on_choice.bind(i), 560.0, false)
		b.custom_minimum_size = Vector2(560.0, 56.0)
		b.disabled = missing or no_fuel
		col.add_child(b)
		_choice_buttons.append(b)
	_build_help(col)
	# the countdown
	_bar = UI.meter(560.0)
	col.add_child(_bar)
	_timer_label = UI.label("", 14, UI.C_MUTED, true)
	_timer_label.custom_minimum_size = Vector2(560.0, 0.0)
	col.add_child(_timer_label)
	_update_timer()


## A free clue and a paid, clearer tip. Hidden until the player asks.
func _build_help(col: VBoxContainer) -> void:
	var hint: String = str(_event.get("hint", ""))
	var advice: String = str(_event.get("advice", ""))
	if hint == "" and advice == "":
		return
	var row: HBoxContainer = UI.hbox(10)
	col.add_child(row)
	if hint != "":
		_clue_btn = UI.button("Clue (free)", _on_clue, 200.0, false)
		_clue_btn.custom_minimum_size = Vector2(200.0, 38.0)
		row.add_child(_clue_btn)
	if advice != "":
		_advice_btn = UI.button("Ask an expert (%s)" % UI.money(ADVICE_COST_K), _on_advice, 260.0, false)
		_advice_btn.custom_minimum_size = Vector2(260.0, 38.0)
		row.add_child(_advice_btn)
	_help_label = UI.label("", 14, UI.C_YELLOW, true)
	_help_label.custom_minimum_size = Vector2(560.0, 0.0)
	_help_label.visible = false
	col.add_child(_help_label)


func _on_clue() -> void:
	_help_label.text = "Clue: " + str(_event.get("hint", ""))
	_help_label.visible = true
	_clue_btn.disabled = true


func _on_advice() -> void:
	advice_paid_k = ADVICE_COST_K
	_help_label.text = "Expert: " + str(_event.get("advice", ""))
	_help_label.visible = true
	_advice_btn.disabled = true
	if _clue_btn != null:
		_clue_btn.disabled = true


func _process(delta: float) -> void:
	if _notice_left >= 0.0:
		_notice_left -= delta
		if _notice_left < 0.0:
			_finish()
		return
	if _done:
		return
	_left -= delta
	if _left <= 0.0:
		_left = 0.0
		_update_timer()
		timed_out = true
		_show_timeout()
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
	_timer_label.text = "Decide in %d seconds. If you don't, flight software decides for you, and you pay a penalty." % int(ceil(_left))


## Time ran out: show what was chosen for the player and what it costs, like a real
## mission where nobody answered in time and the spacecraft's own rules took over.
func _show_timeout() -> void:
	_done = true
	_picked = _default_index
	for item in _choice_buttons:
		var b: Button = item
		b.visible = false
	if _clue_btn != null:
		_clue_btn.get_parent().visible = false
	_bar.visible = false
	var choices: Array = _event.get("choices", [])
	var c: Dictionary = choices[_default_index] if _default_index < choices.size() else {}
	var when: String = str(_event.get("when", "ops"))
	var head: Label = UI.label("Time ran out", 22, UI.C_RED)
	_col.add_child(head)
	_col.move_child(head, _timer_label.get_index())
	var penalty: String = "Penalty: the launch review had to meet again, so launch slips %d days." % Sim.TIMEOUT_DAYS
	var why: String = "On real missions a decision that misses its deadline goes back to the review board, and the schedule slips."
	if when == "ops":
		penalty = "Penalty: the satellite put itself in safe mode, so this week's photos are lost."
		why = "Real spacecraft protect themselves when the ground is silent: they go into safe mode and wait. It keeps them alive but stops the science."
	_timer_label.text = "Chosen for you: %s (%s)\n%s\n%s" % [str(c.get("label", "")), str(c.get("detail", "")), penalty, why]
	_timer_label.add_theme_color_override("font_color", UI.C_TEXT)
	var ok: Button = UI.button("Understood", _finish, 220.0, true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(ok)
	_notice_left = TIMEOUT_NOTICE_SECONDS
	GameState.play_sound("fail")


func _finish() -> void:
	if _notice_left == -2.0:
		return
	_notice_left = -2.0
	chosen.emit(_picked)
	queue_free()


func _on_choice(index: int) -> void:
	if _done:
		return
	_done = true
	_picked = index
	_notice_left = -2.0
	chosen.emit(index)
	queue_free()
