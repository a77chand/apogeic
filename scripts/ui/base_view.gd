## The middle of the screen: one tile per module the base has, is building, or
## has planned this sol. Read-only: it only displays state.
extends PanelContainer

const TileScene = preload("res://scenes/ui/module_tile.tscn")

## Grey-box colors per module. A module not listed here gets GREY.
## (UI colors only; game balance lives in data/.)
const MODULE_COLORS := {
	"solar_panel": Color(0.25, 0.4, 0.85),
	"battery": Color(0.9, 0.75, 0.2),
	"electrolyzer": Color(0.45, 0.75, 1.0),
	"ice_miner": Color(0.6, 0.85, 0.9),
	"greenhouse": Color(0.35, 0.75, 0.3),
	"habitat": Color(0.85, 0.85, 0.8),
	"regolith_shielding": Color(0.55, 0.45, 0.35),
	"storm_shelter": Color(0.6, 0.35, 0.7),
}
const GREY := Color(0.5, 0.5, 0.5)

@onready var title: Label = $Margin/VBox/Title
@onready var grid: GridContainer = $Margin/VBox/Scroll/Grid


func show_state(sim, state: Dictionary, planned: Array) -> void:
	title.text = "Your base on %s" % sim.scenario.name
	# Throw away the old tiles and make fresh ones. remove_child first, because
	# queue_free only deletes the node at the end of the frame.
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for id in sim.modules:
		var count: int = state.modules[id]
		var broken: int = sim.broken_units(state, id)
		# Units that were switched off last sol for lack of power or water.
		var off: int = mini(int(state.last_off.get(id, 0)), count - broken)
		for i in count:
			if i < broken:
				_add_tile(sim, id, "broken")
			elif i < broken + off:
				_add_tile(sim, id, "off")
			else:
				_add_tile(sim, id, "working")
		for p in state.pending:
			if p.module == id:
				_add_tile(sim, id, "building", "%d %s" % [p.sols_left, str(state.day_word).to_lower()])
		for p in planned:
			if p == id:
				_add_tile(sim, id, "planned")


func _add_tile(sim, id: String, status: String, note: String = "") -> void:
	var tile = TileScene.instantiate()
	grid.add_child(tile)  # add first so the tile's @onready variables are set
	tile.setup(id, sim.module_name(id), MODULE_COLORS.get(id, GREY), status, note)
