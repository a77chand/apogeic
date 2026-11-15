extends RefCounted
## The header for the hopping-rover problem: what it is on the left, the title in the middle, and
## the three challenges as tabs on the right (1 sensors, 2 route, 3 moving shadows).
## A challenge opens when the one before it is done; done ones get a tick.

const UI = preload("res://scripts/ui/ui.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")

const NAMES: Array = ["Sensors", "Route", "Shadows"]


static func bar(cfg: Dictionary, current: int) -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 72)
	bar.custom_minimum_size = Vector2(1280, 72)
	var row: HBoxContainer = UI.hbox(14)
	bar.add_child(row)
	var left: VBoxContainer = UI.vbox(0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.custom_minimum_size = Vector2(330.0, 0.0)
	row.add_child(left)
	left.add_child(UI.label("NASA problem: a hopping rover at the Moon's south pole", 13, UI.C_MUTED))
	left.add_child(UI.label("MOSTLY ILLUSTRATIVE NUMBERS", 11, UI.C_ORANGE))
	var title: Label = UI.label(str(cfg.get("title", "Can the rover see?")), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var tabs: HBoxContainer = UI.hbox(6)
	tabs.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(tabs)
	for i in range(NAMES.size()):
		var n: int = i + 1
		var done: bool = GameState.is_truck_done(n)
		var open: bool = n == 1 or GameState.demo_mode or GameState.is_truck_done(n - 1)
		var accent: Color = UI.C_GOLD if n == current else (UI.C_GREEN if done else (UI.C_ACCENT if open else UI.C_DISABLED_BORDER))
		var text: String = "%d %s%s" % [n, str(NAMES[i]), " ✓" if done else ""]
		var b: Button = UI.pixel_button(text, _go.bind(n), 112.0, 34.0, 10, accent)
		b.disabled = not open
		b.tooltip_text = "Finish challenge %d first" % (n - 1) if not open else ""
		tabs.add_child(b)
	return bar


static func _go(n: int) -> void:
	if n == 1:
		GameState.go("truck")
		return
	# the first set of this challenge that is not done yet (or its first set)
	var routes: Array = TruckSim.load_config().get("routes", [])
	var first: int = -1
	for i in range(routes.size()):
		var r: Dictionary = routes[i]
		if int(r.get("challenge", 0)) != n:
			continue
		if first < 0:
			first = i
		if not bool(GameState.truck_sets_done.get(str(r.get("id", "")), false)):
			first = i
			break
	GameState.truck_route = maxi(0, first)
	GameState.go("truck_route")
