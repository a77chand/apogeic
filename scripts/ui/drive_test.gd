extends Control
## The hopping rover's drive test: it drives through the five conditions one after another
## (sunlit ground, dust, long shadows, a crater that never sees sunlight, a crater rim).
## In each one a rock lies ahead. If the chosen sensors cover that condition, the rover
## spots the rock and hops over it; if not, it drives into it and stops. The result
## matches the screen's Covered / Weak / Blind (TruckSim); it is not random.
## Each zone is a fixed little timeline, so the test always ends; 1x / 2x sets the speed.
##   var t: Control = DriveTest.new(); t.cfg = cfg; t.selected = ["lidar"]; add_child(t)
##   await t.finished

const UI = preload("res://scripts/ui/ui.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")

signal finished(all_safe: bool)

const ZONE_SECONDS: float = 3.6
const STAGE: Rect2 = Rect2(140, 110, 1000, 380)
const SLOPE: float = 0.20          # the crater rim rises this much per pixel, left to right

var cfg: Dictionary = {}
var selected: Array = []
var _zones: Array = []
var _t: float = 0.0
var _speed: float = 1.0
var _done: bool = false
var _ended: bool = false          # every zone has played: the picture stays still
var _results: VBoxContainer = null
var _shown: int = 0
var _close: Button = null
var _speed_btn: Button = null


func _ready() -> void:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	var target: float = float(cfg.get("target_detect_pct", 95.0))
	for item in cfg.get("conditions", []):
		var c: Dictionary = item
		var pct: float = TruckSim.detect_chance(cfg, selected, str(c.get("id", ""))) * 100.0
		_zones.append({"id": str(c.get("id", "")), "name": str(c.get("name", "")), "pct": pct, "safe": pct >= target - 0.0001})
	_results = UI.vbox(4)
	_results.position = Vector2(STAGE.position.x, STAGE.end.y + 14.0)
	_results.size = Vector2(STAGE.size.x, 120.0)
	add_child(_results)
	var skip: Button = UI.button("Skip", _finish, 120.0, false)
	skip.position = Vector2(STAGE.end.x - 120.0, STAGE.position.y - 48.0)
	add_child(skip)
	_speed_btn = UI.button("Speed: 1x", _toggle_speed, 150.0, false)
	_speed_btn.position = Vector2(STAGE.end.x - 280.0, STAGE.position.y - 48.0)
	add_child(_speed_btn)
	_close = UI.button("Done", _finish, 200.0, true)
	_close.position = Vector2(STAGE.end.x - 200.0, 640.0)
	_close.visible = false
	add_child(_close)
	GameState.tutorial_open = true


func _exit_tree() -> void:
	GameState.tutorial_open = false


func _toggle_speed() -> void:
	_speed = 2.0 if _speed < 1.5 else 1.0
	_speed_btn.text = "Speed: %dx" % int(_speed)


func _process(delta: float) -> void:
	if _ended:
		return
	_t = minf(_t + delta * _speed, ZONE_SECONDS * float(_zones.size()))
	# write each zone's result as the rover reaches its rock
	while _shown < _zones.size() and _t - float(_shown) * ZONE_SECONDS >= ZONE_SECONDS * 0.6:
		var z: Dictionary = _zones[_shown]
		var word: String = TruckSim.coverage_word(cfg, float(z["pct"])).to_lower()
		var text: String = "%s:  SPOTTED, hopped over it  (sensors: covered)" % str(z["name"]) if bool(z["safe"]) \
				else "%s:  HIT THE ROCK  (sensors: %s here)" % [str(z["name"]), word]
		_results.add_child(UI.label(text, 14, UI.C_GREEN if bool(z["safe"]) else UI.C_RED))
		GameState.play_sound("chime" if bool(z["safe"]) else "fail")
		_shown += 1
	if _t >= ZONE_SECONDS * float(_zones.size()):
		_ended = true
		_close.visible = true
		var safe: int = _zones.filter(func(z: Variant) -> bool: return bool((z as Dictionary)["safe"])).size()
		var line: String = "All 5 zones safe. This rover is ready for the south pole." if safe == _zones.size() else "%d of %d zones safe. Fit sensors that cover the zones where it hit a rock." % [safe, _zones.size()]
		_results.add_child(UI.label(line, 17, UI.C_GOLD if safe == _zones.size() else UI.C_YELLOW))
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	var all_safe: bool = _zones.all(func(z: Variant) -> bool: return bool((z as Dictionary)["safe"]))
	finished.emit(all_safe)
	queue_free()


## The ground height at x in this zone (the crater rim slopes up to the right).
func _ground(x: float, id: String) -> float:
	var gy: float = STAGE.position.y + STAGE.size.y * 0.70
	if id == "slope":
		return gy + 60.0 - (x - STAGE.position.x) * SLOPE
	return gy


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.96))
	var zone: int = mini(int(_t / ZONE_SECONDS), _zones.size() - 1)
	var u: float = clampf((_t - float(zone) * ZONE_SECONDS) / ZONE_SECONDS, 0.0, 1.0)
	var z: Dictionary = _zones[zone]
	var id: String = str(z["id"])
	var r: Rect2 = STAGE
	var ground_col: Color = Color(0.55, 0.55, 0.58)
	if id == "shadow":
		ground_col = Color(0.42, 0.42, 0.45)
	elif id == "dark":
		ground_col = Color(0.05, 0.05, 0.07)
	draw_rect(r, Color(0.01, 0.01, 0.03))
	# the ground: a polygon under the ground line
	draw_colored_polygon(PackedVector2Array([Vector2(r.position.x, _ground(r.position.x, id)), Vector2(r.end.x, _ground(r.end.x, id)), r.end, Vector2(r.position.x, r.end.y)]), ground_col)
	if id == "clear" or id == "shadow" or id == "dust":
		draw_circle(Vector2(r.position.x + 30.0, _ground(r.position.x, id) - 12.0), 14.0, Color(1.0, 0.95, 0.8))
	if id == "shadow":
		var g0: float = _ground(r.position.x + 420.0, id)
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 420.0, g0), Vector2(r.position.x + 900.0, g0), Vector2(r.position.x + 900.0, r.end.y), Vector2(r.position.x + 380.0, r.end.y)]), Color(0.03, 0.03, 0.05))
	# the rock, sitting on the ground
	var rock_x: float = r.position.x + r.size.x * 0.62
	var rock_y: float = _ground(rock_x, id)
	var rock_col: Color = Color(0.32, 0.30, 0.30) if id != "dark" else Color(0.10, 0.10, 0.11)
	draw_colored_polygon(PackedVector2Array([Vector2(rock_x - 26, rock_y), Vector2(rock_x - 16, rock_y - 30), Vector2(rock_x + 8, rock_y - 36), Vector2(rock_x + 26, rock_y - 12), Vector2(rock_x + 24, rock_y)]), rock_col)
	# where the rover is: drive up, then hop over (seen) or drive into the rock (not seen)
	var safe: bool = bool(z["safe"])
	var start_x: float = r.position.x + 80.0
	var stop_x: float = rock_x - 72.0      # where it hops from, or where it hits
	var end_x: float = r.end.x - 80.0
	var x: float = start_x
	var lift: float = 0.0
	var crash: bool = false
	var bump: float = 0.0
	if u < 0.45:
		x = lerpf(start_x, stop_x, u / 0.45)
	elif safe:
		if u < 0.70:
			# the hop: a smooth arc from before the rock to after it
			var k: float = (u - 0.45) / 0.25
			x = lerpf(stop_x, rock_x + 72.0, k)
			lift = sin(k * PI) * 75.0
		else:
			x = lerpf(rock_x + 72.0, end_x, (u - 0.70) / 0.30)
	else:
		# drives into the rock and stops against it, with one small knock back
		var k2: float = clampf((u - 0.45) / 0.12, 0.0, 1.0)
		x = lerpf(stop_x, rock_x - 46.0, k2)
		crash = u > 0.57
		if crash:
			bump = -sin(clampf((u - 0.57) / 0.10, 0.0, 1.0) * PI) * 10.0
	var ground_at: float = _ground(x, id)
	var angle: float = -atan(SLOPE) if id == "slope" else 0.0
	# the sensor beam ahead of the rover: green once it sees the rock
	var sees: bool = safe and u > 0.30
	var beam: Color = UI.C_GREEN if sees else (UI.C_RED if crash else UI.C_ACCENT)
	if not selected.is_empty() and lift < 1.0:
		var bx: Vector2 = Vector2(x + 40.0, ground_at - 30.0)
		draw_colored_polygon(PackedVector2Array([bx, bx + Vector2(220, -44).rotated(angle), bx + Vector2(220, 30).rotated(angle)]), Color(beam, 0.16))
	if sees and u < 0.75:
		draw_arc(Vector2(rock_x, rock_y - 18.0), 34.0, 0.0, TAU, 32, UI.C_GREEN, 2.5)
	_rover(Vector2(x + bump, ground_at - lift), angle, crash)
	if id == "dust":
		for i in range(70):
			var p: Vector2 = Vector2(r.position.x + fmod(float(i) * 131.0 + _t * 60.0, r.size.x), r.position.y + 60.0 + fmod(float(i) * 57.0, r.size.y - 80.0))
			draw_circle(p, 3.0 + float(i % 3), Color(0.70, 0.62, 0.50, 0.35))
	if crash:
		draw_string(UI.pixel_font(), Vector2(rock_x - 140, r.position.y + 58), "ROCK HIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.C_RED)
	elif safe and u > 0.40:
		draw_string(UI.pixel_font(), Vector2(rock_x - 160, r.position.y + 58), "ROCK SPOTTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.C_GREEN)
	draw_rect(r, Color(UI.C_ACCENT, 0.8), false, 2.0)
	draw_string(UI.pixel_font(false), r.position + Vector2(14, 26), "DRIVE TEST  %d/%d  ·  %s" % [zone + 1, _zones.size(), str(z["name"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.C_ACCENT)


## A small hopping rover, side view, standing on point p (the middle of its wheels' base),
## tilted to match the ground.
func _rover(p: Vector2, angle: float, crash: bool) -> void:
	draw_set_transform(p, angle)
	draw_rect(Rect2(Vector2(-48, -50), Vector2(96, 30)), Color(0.90, 0.88, 0.80))
	draw_rect(Rect2(Vector2(-48, -50), Vector2(96, 8)), Color(0.95, 0.60, 0.20))
	draw_rect(Rect2(Vector2(20, -68), Vector2(26, 18)), Color(0.75, 0.78, 0.84))   # sensor mast
	draw_circle(Vector2(42, -60), 5.0, UI.C_RED if crash else Color(0.36, 0.86, 0.95))
	# hop legs folded under the body
	draw_line(Vector2(-30, -20), Vector2(-40, -6), Color(0.6, 0.6, 0.62), 3.0)
	draw_line(Vector2(30, -20), Vector2(40, -6), Color(0.6, 0.6, 0.62), 3.0)
	for wx in [-34.0, 0.0, 34.0]:
		draw_circle(Vector2(wx, -12), 12.0, Color(0.15, 0.15, 0.17))
		draw_circle(Vector2(wx, -12), 5.0, Color(0.55, 0.55, 0.6))
	draw_set_transform(Vector2.ZERO)
