extends Control
## The truck's drive test: it drives through the five conditions one after another (sunlit
## ground, dust, long shadows, a crater that never sees sunlight, a crater rim). In each
## one a rock lies ahead. If the chosen sensors see at least the target share of rocks in
## that condition, the truck spots it, slows and steers round it; if not, it hits it.
## The result matches the numbers on the screen (TruckSim), it is not random.
##   var t: Control = DriveTest.new(); t.cfg = cfg; t.selected = ["lidar"]; add_child(t)
##   await t.finished

const UI = preload("res://scripts/ui/ui.gd")
const TruckSim = preload("res://scripts/core/truck_sim.gd")

signal finished(all_safe: bool)

const ZONE_SECONDS: float = 3.2
const STAGE: Rect2 = Rect2(140, 110, 1000, 380)

var cfg: Dictionary = {}
var selected: Array = []
var _zones: Array = []
var _t: float = 0.0
var _done: bool = false
var _results: VBoxContainer = null
var _shown: int = 0
var _close: Button = null


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
	_close = UI.button("Done", _finish, 200.0, true)
	_close.position = Vector2(STAGE.end.x - 200.0, 640.0)
	_close.visible = false
	add_child(_close)
	GameState.tutorial_open = true


func _exit_tree() -> void:
	GameState.tutorial_open = false


func _process(delta: float) -> void:
	_t += delta
	var zone: int = int(_t / ZONE_SECONDS)
	# write each zone's result as the truck reaches its rock
	while _shown < _zones.size() and (_t - float(_shown) * ZONE_SECONDS) > ZONE_SECONDS * 0.6:
		var z: Dictionary = _zones[_shown]
		var word: String = TruckSim.coverage_word(cfg, float(z["pct"])).to_lower()
		var text: String = "%s:  SPOTTED, steered round it  (sensors: covered)" % str(z["name"]) if bool(z["safe"]) \
				else "%s:  HIT THE ROCK  (sensors: %s here)" % [str(z["name"]), word]
		_results.add_child(UI.label(text, 14, UI.C_GREEN if bool(z["safe"]) else UI.C_RED))
		GameState.play_sound("chime" if bool(z["safe"]) else "fail")
		_shown += 1
	if zone >= _zones.size() and not _close.visible:
		_close.visible = true
		var safe: int = _zones.filter(func(z: Variant) -> bool: return bool((z as Dictionary)["safe"])).size()
		var line: String = "All 5 zones safe. This truck is ready for the south pole." if safe == _zones.size() else "%d of %d zones safe. Fit sensors that cover the zones where it hit a rock." % [safe, _zones.size()]
		_results.add_child(UI.label(line, 17, UI.C_GOLD if safe == _zones.size() else UI.C_YELLOW))
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	var all_safe: bool = _zones.all(func(z: Variant) -> bool: return bool((z as Dictionary)["safe"]))
	finished.emit(all_safe)
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.03, 0.96))
	var zone: int = mini(int(_t / ZONE_SECONDS), _zones.size() - 1)
	var u: float = clampf((_t - float(zone) * ZONE_SECONDS) / ZONE_SECONDS, 0.0, 1.0)
	var z: Dictionary = _zones[zone]
	var id: String = str(z["id"])
	var r: Rect2 = STAGE
	# sky and ground for this zone
	var sky: Color = Color(0.01, 0.01, 0.03)
	var ground: Color = Color(0.55, 0.55, 0.58)
	if id == "shadow":
		ground = Color(0.42, 0.42, 0.45)
	elif id == "dark":
		ground = Color(0.05, 0.05, 0.07)
	draw_rect(r, sky)
	var tilt: float = -0.12 if id == "slope" else 0.0
	var gy: float = r.position.y + r.size.y * 0.68
	var gl: Vector2 = Vector2(r.position.x, gy + r.size.x * 0.5 * -tilt)
	var gr: Vector2 = Vector2(r.end.x, gy - r.size.x * 0.5 * -tilt)
	draw_colored_polygon(PackedVector2Array([gl, gr, Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]), ground)
	# the low Sun far to the left, and the long shadow of a boulder across the path
	if id == "clear" or id == "shadow" or id == "dust":
		draw_circle(Vector2(r.position.x + 30.0, gy - 12.0), 14.0, Color(1.0, 0.95, 0.8))
	if id == "shadow":
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x + 420.0, gy), Vector2(r.position.x + 900.0, gy + 6.0), Vector2(r.position.x + 900.0, r.end.y), Vector2(r.position.x + 380.0, r.end.y)]), Color(0.03, 0.03, 0.05))
	# the rock ahead, and the truck driving towards it
	var rock_x: float = r.position.x + r.size.x * 0.72
	var rock_y: float = gy - (rock_x - r.position.x - r.size.x * 0.5) * tilt
	var rock_col: Color = Color(0.32, 0.30, 0.30) if id != "dark" else Color(0.08, 0.08, 0.09)
	draw_colored_polygon(PackedVector2Array([Vector2(rock_x - 26, rock_y), Vector2(rock_x - 16, rock_y - 30), Vector2(rock_x + 8, rock_y - 36), Vector2(rock_x + 26, rock_y - 12), Vector2(rock_x + 24, rock_y)]), rock_col)
	var safe: bool = bool(z["safe"])
	var tx: float = r.position.x + 80.0 + u * (r.size.x * 0.62)
	var ty_off: float = 0.0
	var crash: bool = false
	if safe and u > 0.55:
		# spotted: steer round it (drive "behind" it on the far side)
		ty_off = -sin(clampf((u - 0.55) / 0.45, 0.0, 1.0) * PI) * 46.0
	elif not safe and u > 0.66:
		tx = rock_x - 70.0
		crash = true
	var ty: float = gy - (tx - r.position.x - r.size.x * 0.5) * tilt + ty_off
	# the sensor beam ahead of the truck: green once it sees the rock, red if it never does
	var sees: bool = safe and u > 0.35
	var beam: Color = UI.C_GREEN if sees else (UI.C_RED if crash else UI.C_ACCENT)
	if not selected.is_empty():
		draw_colored_polygon(PackedVector2Array([Vector2(tx + 40, ty - 26), Vector2(tx + 260, ty - 70), Vector2(tx + 260, ty + 4)]), Color(beam, 0.16))
	if sees:
		draw_arc(Vector2(rock_x, rock_y - 18), 34.0, 0.0, TAU, 32, UI.C_GREEN, 2.5)
	_truck(Vector2(tx, ty), crash)
	# dust in the air
	if id == "dust":
		for i in range(70):
			var p: Vector2 = Vector2(r.position.x + fmod(float(i) * 131.0 + _t * 60.0, r.size.x), r.position.y + 60.0 + fmod(float(i) * 57.0, r.size.y - 80.0))
			draw_circle(p, 3.0 + float(i % 3), Color(0.70, 0.62, 0.50, 0.35))
	if crash:
		draw_string(UI.pixel_font(), Vector2(rock_x - 140, r.position.y + 70), "ROCK HIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.C_RED)
	elif safe and u > 0.4:
		draw_string(UI.pixel_font(), Vector2(rock_x - 160, r.position.y + 70), "ROCK SPOTTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.C_GREEN)
	draw_rect(r, Color(UI.C_ACCENT, 0.8), false, 2.0)
	draw_string(UI.pixel_font(false), r.position + Vector2(14, 26), "DRIVE TEST  %d/%d  ·  %s" % [zone + 1, _zones.size(), str(z["name"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.C_ACCENT)


## A small six-wheeled digging robot, side view.
func _truck(p: Vector2, crash: bool) -> void:
	var shake: Vector2 = Vector2(sin(_t * 60.0) * 3.0, 0) if crash else Vector2.ZERO
	var b: Vector2 = p + shake
	draw_rect(Rect2(b + Vector2(-50, -46), Vector2(96, 30)), Color(0.90, 0.88, 0.80))
	draw_rect(Rect2(b + Vector2(-50, -46), Vector2(96, 8)), Color(0.95, 0.60, 0.20))
	draw_rect(Rect2(b + Vector2(20, -64), Vector2(26, 18)), Color(0.75, 0.78, 0.84))   # sensor mast
	draw_circle(b + Vector2(42, -56), 5.0, Color(0.36, 0.86, 0.95))
	for wx in [-38.0, -4.0, 30.0]:
		draw_circle(b + Vector2(wx, -10), 12.0, Color(0.15, 0.15, 0.17))
		draw_circle(b + Vector2(wx, -10), 5.0, Color(0.55, 0.55, 0.6))
	draw_line(b + Vector2(-50, -36), b + Vector2(-78, -10), Color(0.6, 0.6, 0.62), 4.0)   # digging bucket arm
	draw_rect(Rect2(b + Vector2(-92, -16), Vector2(18, 12)), Color(0.6, 0.6, 0.62))
