## The build list on the right. One button per module, with what it uses and
## makes, written from the data files. Pressing a button asks main.gd to plan it;
## the build happens when the player ends the sol.
extends PanelContainer

signal build_requested(module_id: String)
signal clear_requested

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var planned_label: Label = $Margin/VBox/PlannedLabel
@onready var clear_button: Button = $Margin/VBox/ClearButton

var buttons := {}  # module id -> Button


func _ready() -> void:
	clear_button.pressed.connect(func(): clear_requested.emit())


## Makes the button list. Called at the start of each game (Moon and Mars
## describe solar panels differently).
func setup(sim) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	buttons.clear()
	for id in sim.modules:
		var def: Dictionary = sim.modules[id]
		var button := Button.new()
		button.text = "%s   (%d pts)" % [def.name, int(def.cost)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# The lambda remembers this loop's `id`, so each button plans its own module.
		button.pressed.connect(func(): build_requested.emit(id))
		list.add_child(button)
		buttons[id] = button

		var info := Label.new()
		info.text = describe(sim, def)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 13)
		info.modulate = Color(0.75, 0.78, 0.85)
		list.add_child(info)


## Puts an orange frame around one module's button (the tutorial goal). "" clears it.
func highlight(module_id: String) -> void:
	for id in buttons:
		var button: Button = buttons[id]
		if id == module_id:
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color(0.3, 0.2, 0.1)
			frame.border_color = Color(0.95, 0.6, 0.25)
			frame.set_border_width_all(3)
			frame.set_corner_radius_all(4)
			button.add_theme_stylebox_override("normal", frame)
		else:
			button.remove_theme_stylebox_override("normal")


func show_state(sim, state: Dictionary, planned: Array) -> void:
	for id in buttons:
		var why: String = sim.can_build(state, id, planned)
		var button: Button = buttons[id]
		button.disabled = why != ""
		button.tooltip_text = sim.modules[id].description if why == "" else "Can't build: " + why
	if planned.is_empty():
		planned_label.text = "Planned this %s: nothing yet" % str(state.day_word).to_lower()
	else:
		var names := []
		for id in planned:
			names.append(sim.module_name(id))
		planned_label.text = "Planned: " + ", ".join(names)
	clear_button.disabled = planned.is_empty()


## A one-line summary such as "Uses 3 power, 2 water. Makes 4 oxygen."
## Everything comes from modules.json, so it stays right when numbers change.
func describe(sim, def: Dictionary) -> String:
	var parts := []
	if not def.inputs.is_empty():
		parts.append("Uses " + _amounts(def.inputs, 1.0) + ".")
	if not def.outputs.is_empty():
		var factor := 1.0
		if def.get("uses_sunlight", false):
			factor = float(sim.scenario.solar_multiplier)
		var text := "Makes " + _amounts(def.outputs, factor)
		if def.get("uses_sunlight", false):
			text += " in clear sunlight on " + sim.scenario.name
		parts.append(text + ".")
	if def.has("power_storage"):
		parts.append("Stores %s power." % _num(def.power_storage))
	if def.has("crew_capacity"):
		parts.append("Beds for %s crew. +%s crew health each %s when powered." % [
			_num(def.crew_capacity), _num(def.morale_per_sol), str(sim.scenario.day_word).to_lower()])
	if def.has("background_dose_reduction"):
		parts.append("Blocks %d%% of everyday radiation." % roundi(float(def.background_dose_reduction) * 100.0))
	if def.has("storm_dose_factor"):
		parts.append("Cuts solar storm radiation by %d%%." % roundi((1.0 - float(def.storm_dose_factor)) * 100.0))
	var build_time := int(def.build_time)
	if build_time > 0:
		parts.append("Takes %d %s to build." % [build_time, str(sim.scenario.day_word).to_lower() + ("s" if build_time > 1 else "")])
	return " ".join(parts)


func _amounts(per_unit: Dictionary, factor: float) -> String:
	var parts := []
	for r in per_unit:
		parts.append("%s %s" % [_num(float(per_unit[r]) * factor), r])
	return ", ".join(parts)


## 6.0 -> "6", 3.6 -> "3.6"
func _num(x) -> String:
	var f := float(x)
	if absf(f - roundf(f)) < 0.05:
		return str(roundi(f))
	return "%.1f" % f
