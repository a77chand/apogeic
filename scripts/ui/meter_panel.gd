## The six meters on the left of the screen. Read-only: it only displays state.
extends PanelContainer

@onready var meters: VBoxContainer = $Margin/VBox/Meters


func show_state(sim, state: Dictionary) -> void:
	for bar in meters.get_children():
		var id: String = bar.meter_id
		bar.show_value(state.meters[id], sim.meter_max(state, id), state.deltas[id])
