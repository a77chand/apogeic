extends Control
## Rover challenges 2 and 3: plan a route across the south pole for a light hopping rover.
## Challenge 2 has three sets of maps, each harder; challenge 3 has moving shadows.
## Click squares next to the end of the path to extend it (click the last square again to
## take it back; "Wait" stays a step to charge in sunlight). The map shows the shadows as
## they will be when the rover gets there, so in challenge 3 they move as the plan grows.
## "Drive" plays the route: the rover stops if it can't see rocks or the battery runs flat.
## Rules are in TruckSim (route_eval); the challenge is GameState.truck_route.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")
const TruckTabs = preload("res://scripts/ui/truck_tabs.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

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
var _next_btn: Button = null
var _routes: Array = []
var _speed: float = 1.0          # driving speed: 1x or 2x
var _speed_btn: Button = null    # shows once the plan reaches the dig site


func _ready() -> void:
	_cfg = TruckSim.load_config()
	_routes = _cfg.get("routes", [])
	_route = _routes[clampi(GameState.truck_route, 0, _routes.size() - 1)]
	_path = [TruckSim.route_find(_route, "S")]
	add_child(TruckTabs.bar(_cfg, int(_route.get("challenge", 2))))
	_build_intro()
	_build_map()
	_build_side()
	_build_sets()
	_refresh()
	Tutorial.maybe_show(self, "route" if int(_route.get("challenge", 2)) == 2 else "shadows")


## Set 1 / 2 / 3 of this challenge, with a tick on the ones done. A set opens when the
## one before it is done.
func _build_sets() -> void:
	var mine: Array = []
	for i in range(_routes.size()):
		if int((_routes[i] as Dictionary).get("challenge", 0)) == int(_route.get("challenge", 0)):
			mine.append(i)
	if mine.size() <= 1:
		return
	var row: HBoxContainer = UI.hbox(8)
	_place(row, Vector2(210, 650), Vector2(400, 40))
	for k in range(mine.size()):
		var i: int = mine[k]
		var r: Dictionary = _routes[i]
		var done: bool = _set_done(i)
		var open: bool = k == 0 or GameState.demo_mode or _set_done(int(mine[k - 1]))
		var accent: Color = UI.C_GOLD if i == GameState.truck_route else (UI.C_GREEN if done else (UI.C_ACCENT if open else UI.C_DISABLED_BORDER))
		var b: Button = UI.pixel_button("Set %d%s" % [k + 1, " ✓" if done else ""], _go_route.bind(i), 110.0, 40.0, 11, accent)
		b.disabled = not open
		row.add_child(b)


func _set_done(i: int) -> bool:
	return bool(GameState.truck_sets_done.get(str((_routes[i] as Dictionary).get("id", "")), false))


func _go_route(i: int) -> void:
	GameState.truck_route = i
	GameState.go("truck_route")


## Keyboard: WASD or the arrow keys move the end of the path; moving back onto the last
## square takes it back. Backspace undoes, Space waits (when allowed), Enter drives.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or _driving >= 0.0:
		return
	var k: int = (event as InputEventKey).physical_keycode
	var d: Vector2i = Vector2i.ZERO
	match k:
		KEY_W, KEY_UP:
			d = Vector2i(0, -1)
		KEY_S, KEY_DOWN:
			d = Vector2i(0, 1)
		KEY_A, KEY_LEFT:
			d = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT:
			d = Vector2i(1, 0)
		KEY_BACKSPACE:
			_on_undo()
		KEY_SPACE:
			if bool(_route.get("waits", false)):
				_on_wait()
		KEY_ENTER, KEY_KP_ENTER:
			_on_drive()
	if d != Vector2i.ZERO:
		_step_to(_path[_path.size() - 1] + d)
	get_viewport().set_input_as_handled()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_intro() -> void:
	var l: Label = UI.label("%s: %s" % [str(_route.get("title", "")), str(_route.get("intro", ""))], 14, UI.C_TEXT, true)
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
	col.add_child(UI.label("Hopping rover: camera, stereo camera, headlights", 12, UI.C_MUTED, true))
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
	var drive_row: HBoxContainer = UI.hbox(8)
	col.add_child(drive_row)
	drive_row.add_child(UI.button("Drive  >", _on_drive, 230.0, true))
	_speed_btn = UI.button("Speed 1x", _toggle_speed, 92.0, false)
	_speed_btn.tooltip_text = "Drive at normal or double speed"
	_speed_btn.visible = false
	drive_row.add_child(_speed_btn)
	_next_btn = UI.button("Next  >", _on_next, 330.0, true)
	_next_btn.visible = _set_done(GameState.truck_route)
	col.add_child(_next_btn)
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
		_status.text = "The plan reaches the dig site. Press Drive (1x or 2x speed)."
		_status.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		_status.text = "Click a square next to the end of the path."
		_status.add_theme_color_override("font_color", UI.C_MUTED)
	_map.queue_redraw()
	# the speed choice appears once the path is finished (it reaches the dig site)
	if _speed_btn != null:
		_speed_btn.visible = bool(_result.get("reached", false)) or _driving >= 0.0


func _toggle_speed() -> void:
	_speed = 2.0 if _speed < 1.5 else 1.0
	_speed_btn.text = "Speed %dx" % int(_speed)


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
	if _path.size() > 1 and c == _path[_path.size() - 1]:
		_on_undo()
		return
	_step_to(c)


## Extends the path to square c (next to its end). Stepping back onto the square before
## the end takes the last step back; the rover can't cross its own tracks or a ridge.
func _step_to(c: Vector2i) -> void:
	var last: Vector2i = _path[_path.size() - 1]
	if _path.size() > 1 and c == _path[_path.size() - 2]:
		_on_undo()
		return
	if absi(c.x - last.x) + absi(c.y - last.y) != 1 or TruckSim.route_cell(_route, c) == "#":
		GameState.play_sound("fail")
		_status.text = "Pick a square next to the end of the path (not a ridge)."
		return
	if _path.has(c):
		GameState.play_sound("fail")
		_status.text = "The rover can't drive back over its own tracks."
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
		_driving = minf(float(stop), _driving + get_process_delta_time() * 2.5 * _speed)
		_map.queue_redraw()
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if bool(_result.get("ok", false)):
		GameState.play_sound("fanfare")
		_mark_done()
		_status.text = "Arrived safely! " + str(_route.get("lesson", ""))
		_status.add_theme_color_override("font_color", UI.C_GREEN)
		_next_btn.visible = true
		_good_job()
	else:
		GameState.play_sound("fail")
		_status.text = (str(_result.get("fail", "")) if str(_result.get("fail", "")) != "" else "The route stops before the dig site.") + " Change the plan and try again."
		_status.add_theme_color_override("font_color", UI.C_RED)
	_driving = -1.0
	_map.queue_redraw()


## A small "Good job!" box over the map when a set is finished. It closes by itself after a
## few seconds, or on a click.
func _good_job() -> void:
	var ch: int = int(_route.get("challenge", 2))
	var total: int = 0
	var done: int = 0
	for i in range(_routes.size()):
		if int((_routes[i] as Dictionary).get("challenge", 0)) == ch:
			total += 1
			if _set_done(i):
				done += 1
	var box: PanelContainer = UI.neon_panel(UI.C_GREEN, 18.0)
	box.z_index = 50
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	var col: VBoxContainer = UI.vbox(6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(col)
	var head: Label = UI.label("Good job!", 30, UI.C_GREEN)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var line: String = "Set %d of %d done." % [int(_route.get("set", done)), total]
	if done >= total:
		line = "All %d sets done: challenge %d complete!" % [total, ch]
	var l: Label = UI.label(line, 17, UI.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var more: Label = UI.label("Press Next for the next one.", 13, UI.C_MUTED)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(more)
	box.custom_minimum_size = Vector2(380.0, 0.0)
	box.position = Vector2(ORIGIN.x + 230.0, ORIGIN.y + 150.0)
	box.pivot_offset = Vector2(190.0, 70.0)
	box.scale = Vector2(0.6, 0.6)
	var tw: Tween = box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)
	box.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and is_instance_valid(box):
			box.queue_free())


## This set is done; when every set of the challenge is done, the challenge is too.
func _mark_done() -> void:
	GameState.truck_sets_done[str(_route.get("id", ""))] = true
	var ch: int = int(_route.get("challenge", 2))
	var all_done: bool = true
	for i in range(_routes.size()):
		if int((_routes[i] as Dictionary).get("challenge", 0)) == ch and not _set_done(i):
			all_done = false
	if all_done:
		GameState.mark_truck_done(ch)
	else:
		GameState.save_game()


## The next set, the next challenge, or home after the last one.
func _on_next() -> void:
	var i: int = GameState.truck_route + 1
	if i < _routes.size():
		GameState.truck_route = i
		GameState.go("truck_route")
	else:
		GameState.go("title")


func _on_back() -> void:
	GameState.go("truck")
