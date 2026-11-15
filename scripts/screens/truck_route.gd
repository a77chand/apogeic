extends Control
## Truck challenges 2 and 3: plan a route across the south pole for a light scout rover.
## Click squares next to the end of the path to extend it (click the last square again to
## take it back; "Wait" stays a step to charge in sunlight). The map shows the shadows as
## they will be when the rover gets there, so in challenge 3 they move as the plan grows.
## "Drive" plays the route: the rover stops if it can't see rocks or the battery runs flat.
## Rules are in TruckSim (route_eval); the challenge is GameState.truck_route.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")
const TruckTabs = preload("res://scripts/ui/truck_tabs.gd")

const CELL: float = 60.0
const ORIGIN: Vector2 = Vector2(30, 150)

var _cfg: Dictionary = {}
var _route: Dictionary = {}
var _path: Array = []
var _map: Control = null
var _battery_bar: ProgressBar = null
var _battery_label: Label = null
var _status: Label = null
var _driving: float = -1.0   # step being shown while driving, -1 = planning
var _result: Dictionary = {}


func _ready() -> void:
	_cfg = TruckSim.load_config()
	var routes: Array = _cfg.get("routes", [])
	_route = routes[clampi(GameState.truck_route, 0, routes.size() - 1)]
	_path = [TruckSim.route_find(_route, "S")]
	add_child(TruckTabs.bar(_cfg, GameState.truck_route + 1))
	_build_intro()
	_build_map()
	_build_side()
	_refresh()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_intro() -> void:
	var l: Label = UI.label(str(_route.get("intro", "")), 14, UI.C_TEXT, true)
	l.custom_minimum_size = Vector2(1220.0, 0.0)
	_place(l, Vector2(30, 82), Vector2(1220, 60))


func _build_map() -> void:
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	var grid: Array = _route.get("grid", [])
	_place(_map, ORIGIN, Vector2(CELL * float(str(grid[0]).length()), CELL * float(grid.size())))


func _build_side() -> void:
	var panel: PanelContainer = UI.neon_panel(UI.C_CYAN, 14.0)
	_place(panel, Vector2(890, 150), Vector2(370, 480))
	var col: VBoxContainer = UI.vbox(8)
	panel.add_child(col)
	col.add_child(UI.label("Battery", 18))
	_battery_bar = UI.meter(330.0)
	col.add_child(_battery_bar)
	_battery_label = UI.label("", 14)
	col.add_child(_battery_label)
	col.add_child(UI.label("Scout rover: camera, stereo camera, headlights", 12, UI.C_MUTED, true))
	# a small key to the map
	for item in [["Sunlight: charges the battery", Color(0.72, 0.70, 0.62)], ["Shadow / dark crater: drains it", Color(0.10, 0.10, 0.16)],
			["Digging dust: can't see rocks", Color(0.62, 0.48, 0.30)], ["Slope", Color(0.55, 0.52, 0.48)], ["Ridge: can't cross", Color(0.30, 0.28, 0.34)]]:
		var row: HBoxContainer = UI.hbox(8)
		col.add_child(row)
		var sw: ColorRect = ColorRect.new()
		sw.color = item[1]
		sw.custom_minimum_size = Vector2(18, 18)
		row.add_child(sw)
		row.add_child(UI.label(str(item[0]), 13, UI.C_TEXT))
	_status = UI.label("", 14, UI.C_YELLOW, true)
	_status.custom_minimum_size = Vector2(330.0, 0.0)
	col.add_child(_status)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var row2: HBoxContainer = UI.hbox(8)
	col.add_child(row2)
	row2.add_child(UI.button("Undo", _on_undo, 100.0, false))
	if bool(_route.get("waits", false)):
		row2.add_child(UI.button("Wait", _on_wait, 100.0, false))
	row2.add_child(UI.button("Clear", _on_clear, 100.0, false))
	col.add_child(UI.button("Drive  >", _on_drive, 330.0, true))
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(30, 650), Vector2(160, 52))


## Shadows as they will be at a step of the plan.
func _shadows_at(t: int) -> Dictionary:
	return TruckSim.route_shadows(_cfg, _route, t)


func _refresh() -> void:
	_result = TruckSim.route_eval(_cfg, _route, _path)
	var b: float = float(_result.get("battery", float(_route.get("battery", 10))))
	var cap: float = float(_route.get("capacity", 30))
	UI.set_meter(_battery_bar, b / cap * 100.0, "green" if b > cap * 0.3 else ("yellow" if b > 0.0 else "red"))
	_battery_label.text = "%d of %d after %d steps" % [int(b), int(cap), _path.size() - 1]
	if str(_result.get("fail", "")) != "":
		_status.text = str(_result["fail"])
		_status.add_theme_color_override("font_color", UI.C_RED)
	elif bool(_result.get("reached", false)):
		_status.text = "The plan reaches the dig site. Press Drive."
		_status.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		_status.text = "Click a square next to the end of the path."
		_status.add_theme_color_override("font_color", UI.C_MUTED)
	_map.queue_redraw()


func _draw_map() -> void:
	var grid: Array = _route.get("grid", [])
	var t_now: int = _path.size() if _driving < 0.0 else int(_driving)
	var sh: Dictionary = _shadows_at(t_now)
	for y in range(grid.size()):
		var row: String = str(grid[y])
		for x in range(row.length()):
			var c: Vector2i = Vector2i(x, y)
			var r: Rect2 = Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-1.0)
			var letter: String = row[x]
			var cond: String = TruckSim.route_condition(_route, c, sh)
			var col: Color = Color(0.72, 0.70, 0.62)
			if letter == "#":
				col = Color(0.30, 0.28, 0.34)
			elif cond == "dark":
				col = Color(0.06, 0.06, 0.10)
			elif cond == "shadow":
				col = Color(0.14, 0.14, 0.20)
			elif cond == "dust":
				col = Color(0.62, 0.48, 0.30)
			elif cond == "slope":
				col = Color(0.55, 0.52, 0.48)
			_map.draw_rect(r, col)
			if letter == "#":
				_map.draw_line(r.position + Vector2(6, r.size.y - 6), r.position + Vector2(r.size.x * 0.5, 8), Color(0.5, 0.48, 0.55), 2.0)
				_map.draw_line(r.position + Vector2(r.size.x * 0.5, 8), r.end - Vector2(6, 6), Color(0.5, 0.48, 0.55), 2.0)
			if letter == "D":
				for k in range(5):
					_map.draw_circle(r.position + Vector2(10 + k * 9, 14 + (k % 2) * 20), 4.0, Color(0.85, 0.70, 0.45, 0.6))
			if letter == "S" or letter == "G":
				_map.draw_rect(r, Color(UI.C_GOLD, 0.25))
				_map.draw_string(UI.pixel_font(false), r.position + Vector2(5, 14), "START" if letter == "S" else "DIG", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 10, UI.C_GOLD)
	# the Sun's direction, as an arrow at the edge
	var az: float = deg_to_rad(float(_route.get("sun_az", 180.0)) + float(_route.get("sun_step_deg", 0.0)) * float(t_now))
	var to_sun: Vector2 = Vector2(cos(az), -sin(az))
	# on the edge of the map, in the direction of the Sun
	var centre: Vector2 = _map.size * 0.5
	var reach: float = minf(centre.x / maxf(0.001, absf(to_sun.x)), centre.y / maxf(0.001, absf(to_sun.y)))
	var edge: Vector2 = centre + to_sun * (reach - 16.0)
	_map.draw_circle(edge, 14.0, Color(1.0, 0.92, 0.6))
	_map.draw_string(UI.pixel_font(false), edge + Vector2(-16, 30), "SUN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.92, 0.6))
	# the planned path: dots coloured by whether the rover sees rocks there
	var steps: Array = _result.get("steps", [])
	for i in range(_path.size()):
		var c: Vector2i = _path[i]
		var p: Vector2 = Vector2(c) * CELL + Vector2(CELL, CELL) * 0.5
		if i > 0:
			var q: Vector2 = Vector2(_path[i - 1]) * CELL + Vector2(CELL, CELL) * 0.5
			_map.draw_line(q, p, Color(UI.C_ACCENT, 0.8), 4.0)
		var safe: bool = i == 0 or bool((steps[i - 1] as Dictionary).get("safe", true))
		var flat: bool = i > 0 and float((steps[i - 1] as Dictionary).get("battery", 1.0)) <= 0.0
		_map.draw_circle(p, 8.0, UI.C_GREEN if safe and not flat else UI.C_RED)
		if i > 0 and bool((steps[i - 1] as Dictionary).get("wait", false)):
			_map.draw_arc(p, 14.0, 0.0, TAU, 20, UI.C_GOLD, 2.0)
	# the rover while driving
	if _driving >= 0.0:
		var i0: int = clampi(int(_driving), 0, _path.size() - 1)
		var i1: int = clampi(i0 + 1, 0, _path.size() - 1)
		var u: float = _driving - float(i0)
		var a: Vector2 = Vector2(_path[i0]) * CELL + Vector2(CELL, CELL) * 0.5
		var b: Vector2 = Vector2(_path[i1]) * CELL + Vector2(CELL, CELL) * 0.5
		var rp: Vector2 = a.lerp(b, u)
		_map.draw_rect(Rect2(rp - Vector2(16, 12), Vector2(32, 18)), Color(0.92, 0.90, 0.82))
		_map.draw_rect(Rect2(rp - Vector2(16, 12), Vector2(32, 4)), Color(0.95, 0.60, 0.20))
		for wx in [-11.0, 0.0, 11.0]:
			_map.draw_circle(rp + Vector2(wx, 8), 5.0, Color(0.15, 0.15, 0.17))


func _on_map_input(event: InputEvent) -> void:
	if _driving >= 0.0 or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var c: Vector2i = Vector2i(int(event.position.x / CELL), int(event.position.y / CELL))
	var last: Vector2i = _path[_path.size() - 1]
	if _path.size() > 1 and c == last:
		_on_undo()
		return
	if absi(c.x - last.x) + absi(c.y - last.y) != 1 or TruckSim.route_cell(_route, c) == "#":
		GameState.play_sound("fail")
		_status.text = "Pick a square next to the end of the path (not a ridge)."
		return
	_path.append(c)
	GameState.play_sound("select")
	_refresh()


func _on_undo() -> void:
	if _path.size() > 1 and _driving < 0.0:
		_path.pop_back()
		_refresh()


func _on_wait() -> void:
	if _driving < 0.0:
		_path.append(_path[_path.size() - 1])
		GameState.play_sound("select")
		_refresh()


func _on_clear() -> void:
	if _driving < 0.0:
		_path = [_path[0]]
		_refresh()


## Plays the route step by step; stops where it fails.
func _on_drive() -> void:
	if _driving >= 0.0:
		return
	var steps: Array = _result.get("steps", [])
	var stop: int = _path.size() - 1
	for i in range(steps.size()):
		var s: Dictionary = steps[i]
		if not bool(s.get("safe", true)) or float(s.get("battery", 1.0)) <= 0.0:
			stop = i + 1
			break
	_driving = 0.0
	while _driving < float(stop):
		_driving = minf(float(stop), _driving + get_process_delta_time() * 2.5)
		_map.queue_redraw()
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if bool(_result.get("ok", false)):
		GameState.play_sound("fanfare")
		GameState.mark_truck_done(GameState.truck_route + 1)
		_status.text = "Arrived safely! " + str(_route.get("lesson", ""))
		_status.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		GameState.play_sound("fail")
		_status.text = (str(_result.get("fail", "")) if str(_result.get("fail", "")) != "" else "The route stops before the dig site.") + " Change the plan and try again."
		_status.add_theme_color_override("font_color", UI.C_RED)
	_driving = -1.0
	_map.queue_redraw()


func _on_back() -> void:
	GameState.go("truck")
