## Under the meters: warnings for what's coming next sol, and what's happening now.
## Read-only: it only displays state.
extends PanelContainer

const WARN_COLOR := Color(1, 0.8, 0.35)
const NOW_COLOR := Color(1, 0.5, 0.45)
const CALM_COLOR := Color(0.6, 0.65, 0.7)

@onready var list: VBoxContainer = $Margin/VBox/List


func show_state(sim, state: Dictionary) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var day := str(state.day_word).to_lower()

	# Coming soon (we only know about events within their warning time).
	for e in sim.warnings(state):
		var sols_until: int = e.start_sol - state.sol
		var when := "Next %s" % day if sols_until == 1 else "In %d %ss" % [sols_until, day]
		_add_line("%s: %s" % [when, sim.event_name(e.id)], WARN_COLOR)

	# Happening now.
	for e in sim.active_events(state, state.sol):
		var left: int = e.start_sol + e.duration - state.sol
		var left_text := "1 %s left" % day if left == 1 else "%d %ss left" % [left, day]
		if e.target != "":
			_add_line("Now: %s broken (%s)" % [sim.module_name(e.target), left_text], NOW_COLOR)
		else:
			_add_line("Now: %s (%s)" % [sim.event_name(e.id), left_text], NOW_COLOR)

	var sunlight: float = sim.sunlight_on(state, state.sol) / float(sim.scenario.solar_multiplier)
	if sunlight < 1.0:
		_add_line("Sunlight today: %d%%" % roundi(sunlight * 100.0), NOW_COLOR)

	if list.get_child_count() == 0:
		_add_line("All quiet. No warnings.", CALM_COLOR)


func _add_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	list.add_child(label)
