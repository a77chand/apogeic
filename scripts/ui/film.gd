extends Control
## A short animated clip, drawn in code, that shows what happens when a design goes wrong
## (or right): the rocket breaking up when it is too heavy, the battery dying in Earth's
## shadow, photos piling up and getting lost, the money running out, the rocket leaving
## without you, a fault that got through testing. The caption types itself out underneath.
## The player can skip it at any time.
##
##   var film: Control = Film.play(self, "launch_fail", ["Too heavy.", "The rocket ..."])
##   await film.finished
##
## Kinds: launch_fail, launch_ok, power_fail, power_ok, data_fail, budget_fail, late, fault.

const UI = preload("res://scripts/ui/ui.gd")
const Self = preload("res://scripts/ui/film.gd")

signal finished

const DURATION: float = 7.0
const BOX: Rect2 = Rect2(190, 60, 900, 460)       # where the clip sits on screen
const SCREEN: Rect2 = Rect2(0, 0, 900, 460)       # the clip's own coordinates
const CHARS_PER_SECOND: float = 45.0

var kind: String = ""
var lines: Array = []
var _t: float = 0.0
var _caption: Label = null
var _full_text: String = ""
var _continue: Button = null
var _done: bool = false
var _c: Control = null   # the stage: the scene is drawn here, clipped to its frame

## The team's drawings. Each one falls back to the code drawing if its file is missing.
const ROCKET_FRAMES: int = 19
const ROCKET_PATH: String = "res://art/animations/rocket/rocket_%02d.png"
## Where the rocket sits inside each frame (pixels): the middle of the body and the fin tips.
const ROCKET_ANCHOR: Vector2 = Vector2(118.0, 176.0)
const ROCKET_SCALE: float = 0.85
var _rocket_frames: Array = []
var _sun_tex: Texture2D = null
var _earth_tex: Texture2D = null
var _station_tex: Texture2D = null
var _banner_ok: Texture2D = null
var _banner_fail: Texture2D = null


static func play(host: Node, film_kind: String, caption: Array) -> Control:
	var f: Control = Self.new()
	f.kind = film_kind
	f.lines = caption
	host.add_child(f)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return f


func _ready() -> void:
	z_index = 100   # always above the screen, including raised cards
	_load_art()
	_c = Control.new()
	_c.clip_contents = true
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.position = BOX.position
	_c.size = BOX.size
	_c.draw.connect(_draw_stage)
	add_child(_c)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.tutorial_open = true
	_full_text = "\n".join(PackedStringArray(lines))
	_caption = UI.label("", 17, UI.C_TEXT, true)
	_caption.position = Vector2(BOX.position.x, BOX.end.y + 18.0)
	_caption.custom_minimum_size = Vector2(BOX.size.x, 0.0)
	_caption.size = Vector2(BOX.size.x, 110.0)
	_caption.visible_characters = 0
	_caption.text = _full_text
	add_child(_caption)
	var skip: Button = UI.button("Skip", _finish, 120.0, false)
	skip.position = Vector2(BOX.end.x - 120.0, BOX.position.y - 48.0)
	add_child(skip)
	_continue = UI.button("Continue", _finish, 200.0, true)
	_continue.position = Vector2(BOX.end.x - 200.0, 650.0)
	_continue.visible = false
	add_child(_continue)
	var sound: String = "fail" if kind.ends_with("fail") or kind in ["late", "fault"] else "chime"
	if kind.begins_with("launch"):
		GameState.play_sound("rumble")
	get_tree().create_timer(3.8).timeout.connect(func() -> void:
		if is_inside_tree():
			GameState.play_sound(sound))


func _load_art() -> void:
	for i in range(1, ROCKET_FRAMES + 1):
		var path: String = ROCKET_PATH % i
		if not ResourceLoader.exists(path):
			_rocket_frames.clear()
			break
		_rocket_frames.append(load(path))
	_sun_tex = _tex("res://art/backgrounds/sun.png")
	_earth_tex = _tex("res://art/backgrounds/earth_dark.png")
	_station_tex = _tex("res://art/modules/ground_station.png")
	_banner_ok = _tex("res://art/ui/mission_completed.png")
	_banner_fail = _tex("res://art/ui/mission_failed.png")


func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


## A texture drawn into a box, keeping its shape, centred on `centre`.
func _draw_fit(tex: Texture2D, centre: Vector2, box: Vector2, tint: Color = Color(1, 1, 1)) -> void:
	var k: float = minf(box.x / float(tex.get_width()), box.y / float(tex.get_height()))
	var sz: Vector2 = Vector2(tex.get_width(), tex.get_height()) * k
	_c.draw_texture_rect(tex, Rect2(centre - sz * 0.5, sz), false, tint)


func _exit_tree() -> void:
	GameState.tutorial_open = false


func _process(delta: float) -> void:
	_t += delta
	_caption.visible_characters = int(_t * CHARS_PER_SECOND)
	if _t >= DURATION * 0.6 and not _continue.visible:
		_continue.visible = true
	queue_redraw()
	_c.queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.82))


func _draw_stage() -> void:
	var r: Rect2 = SCREEN
	_c.draw_rect(r, Color(0.01, 0.02, 0.06))
	# a few fixed stars
	for i in range(60):
		var p: Vector2 = r.position + Vector2(fmod(float(i) * 137.0, r.size.x), fmod(float(i) * 71.0, r.size.y))
		_c.draw_circle(p, 1.0 + float(i % 3) * 0.4, Color(1, 1, 1, 0.25 + 0.2 * float(i % 4)))
	match kind:
		"launch_fail":
			_launch(false)
		"launch_ok":
			_launch(true)
		"power_fail":
			_power(false)
		"power_ok":
			_power(true)
		"data_fail":
			_data()
		"budget_fail":
			_budget()
		"late":
			_late()
		"fault":
			_fault()
	_c.draw_rect(r, Color(UI.C_ACCENT, 0.7), false, 2.0)
	# "replay" style label in the corner
	_c.draw_string(UI.pixel_font(false), r.position + Vector2(14, 24), "SIMULATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.C_ACCENT, 0.8))
	if fmod(_t, 1.0) < 0.5:
		_c.draw_circle(r.position + Vector2(118, 19), 5.0, UI.C_RED)


# ---------------------------------------------------------------- pieces

## The rocket standing on `base` (the fin tips). `lit_for` is how long the engine has been
## burning: the team's frames go from ignition smoke to a full flame, then the last four loop.
func _rocket(base: Vector2, angle: float, flame: bool, lit_for: float = 10.0) -> void:
	if not _rocket_frames.is_empty():
		var idx: int = 0
		if flame:
			var f: int = int(maxf(0.0, lit_for) * 8.0)
			idx = f if f < 15 else 15 + (f - 15) % 4
		var tex: Texture2D = _rocket_frames[clampi(idx, 0, _rocket_frames.size() - 1)]
		_c.draw_set_transform(base, angle, Vector2.ONE * ROCKET_SCALE)
		_c.draw_texture(tex, -ROCKET_ANCHOR)
		_c.draw_set_transform(Vector2.ZERO)
		return
	_c.draw_set_transform(base, angle)
	var body: Color = Color(0.92, 0.93, 0.96)
	_c.draw_rect(Rect2(-14, -120, 28, 110), body)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(-14, -120), Vector2(0, -150), Vector2(14, -120)]), Color(0.85, 0.25, 0.25))
	_c.draw_rect(Rect2(-14, -70, 28, 6), Color(0.85, 0.25, 0.25))
	_c.draw_colored_polygon(PackedVector2Array([Vector2(-14, -30), Vector2(-28, -6), Vector2(-14, -10)]), Color(0.6, 0.62, 0.7))
	_c.draw_colored_polygon(PackedVector2Array([Vector2(14, -30), Vector2(28, -6), Vector2(14, -10)]), Color(0.6, 0.62, 0.7))
	if flame:
		var fl: float = 40.0 + sin(_t * 40.0) * 8.0
		_c.draw_colored_polygon(PackedVector2Array([Vector2(-11, -10), Vector2(0, -10 + fl * 1.6), Vector2(11, -10)]), Color(1.0, 0.62, 0.15))
		_c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -10), Vector2(0, -10 + fl), Vector2(6, -10)]), Color(1.0, 0.95, 0.6))
	_c.draw_set_transform(Vector2.ZERO)


func _satellite(c: Vector2, angle: float, lit: bool) -> void:
	_c.draw_set_transform(c, angle)
	_c.draw_rect(Rect2(-12, -12, 24, 24), Color(0.85, 0.75, 0.45) if lit else Color(0.35, 0.33, 0.3))
	_c.draw_rect(Rect2(-52, -8, 36, 16), Color(0.25, 0.45, 0.9) if lit else Color(0.15, 0.2, 0.35))
	_c.draw_rect(Rect2(16, -8, 36, 16), Color(0.25, 0.45, 0.9) if lit else Color(0.15, 0.2, 0.35))
	if lit and fmod(_t, 0.8) < 0.4:
		_c.draw_circle(Vector2(0, -16), 3.0, UI.C_GREEN)
	_c.draw_set_transform(Vector2.ZERO)


## A labelled bar. bad_above: the bar turns red above this (for "limit used" gauges).
func _gauge(pos: Vector2, label: String, pct: float, warn_below: float, bad_above: float = 1000.0) -> void:
	var w: float = 220.0
	_c.draw_string(ThemeDB.fallback_font, pos + Vector2(0, -6), "%s %d%%" % [label, int(round(pct))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
	_c.draw_rect(Rect2(pos, Vector2(w, 16)), Color(1, 1, 1, 0.12))
	var c: Color = UI.C_GREEN if pct > warn_below and pct <= bad_above else UI.C_RED
	_c.draw_rect(Rect2(pos, Vector2(w * clampf(pct, 0.0, 100.0) / 100.0, 16)), c)
	_c.draw_rect(Rect2(pos, Vector2(w, 16)), Color(1, 1, 1, 0.5), false, 1.0)


func _big_text(text: String, color: Color, at: float) -> void:
	if _t < at:
		return
	var k: float = clampf((_t - at) * 3.0, 0.0, 1.0)
	var banner: Texture2D = _banner_ok if color == UI.C_GREEN else _banner_fail
	if banner != null:
		# the team's MISSION COMPLETED / MISSION FAILED drawing, popping in, with what happened under it
		var mid: Vector2 = Vector2(SCREEN.get_center().x, SCREEN.position.y + 175.0)
		var grow: float = lerpf(1.25, 1.0, k)
		_c.draw_rect(Rect2(SCREEN.position.x + 40.0, mid.y - 52.0, SCREEN.size.x - 80.0, 104.0), Color(0, 0, 0, 0.62 * k))
		_draw_fit(banner, mid + Vector2(0, -12), Vector2(780.0, 60.0) * grow, Color(1, 1, 1, k))
		var small: Font = UI.pixel_font(false)
		var tw: float = small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_c.draw_string(small, Vector2(mid.x - tw * 0.5, mid.y + 38.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(color, k))
		return
	var font: Font = UI.pixel_font()
	var fs: int = 44
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	while w > SCREEN.size.x - 80.0 and fs > 16:
		fs -= 2
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_c.draw_rect(Rect2(SCREEN.get_center().x - w * 0.5 - 16.0, SCREEN.position.y + 196.0 - fs, w + 32.0, fs + 24.0), Color(0, 0, 0, 0.6 * k))
	_c.draw_string(font, Vector2(SCREEN.get_center().x - w * 0.5, SCREEN.position.y + 200), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, k))


# ---------------------------------------------------------------- scenes

func _launch(ok: bool) -> void:
	var r: Rect2 = SCREEN
	var ground_y: float = r.end.y - 40.0
	_c.draw_rect(Rect2(r.position.x, ground_y, r.size.x, 40), Color(0.12, 0.14, 0.18))
	_c.draw_rect(Rect2(r.get_center().x - 60, ground_y - 8, 120, 8), Color(0.3, 0.32, 0.38))
	var climb: float = 0.0
	if ok:
		climb = pow(maxf(0.0, _t - 0.6), 2.0) * 40.0
	else:
		climb = pow(maxf(0.0, minf(_t, 4.0) - 0.6), 1.6) * 22.0
	var base: Vector2 = Vector2(r.get_center().x, ground_y - 8.0 - climb)
	var angle: float = 0.0
	if not ok and _t > 2.6:
		angle = sin(_t * 9.0) * 0.08 * (_t - 2.6) + (_t - 2.6) * 0.25
	# smoke on the pad
	for i in range(10):
		var a: float = float(i) * 0.7
		var rad: float = 20.0 + minf(_t, 3.0) * 12.0 + float(i % 3) * 8.0
		_c.draw_circle(Vector2(r.get_center().x + cos(a) * rad * 1.8, ground_y - 6.0 - absf(sin(a)) * 10.0), rad * 0.5, Color(0.8, 0.8, 0.85, 0.18))
	if ok or _t < 4.0:
		_rocket(base, angle, true, _t)
	if not ok:
		# the speed stops growing the moment the rocket breaks up (t = 4 s)
		_gauge(r.position + Vector2(30, 70), "SPEED NEEDED FOR ORBIT", minf(100.0, minf(_t, 4.0) * 9.0), 60.0)
		_gauge(r.position + Vector2(30, 120), "MASS LIMIT USED", 118.0, -1.0, 100.0)
		if _t > 2.6 and _t < 4.0:
			_c.draw_string(ThemeDB.fallback_font, base + Vector2(40, -80), "MAX-Q: too slow, too heavy", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.C_RED)
		if _t >= 4.0:
			var k: float = _t - 4.0
			for i in range(26):
				var a: float = TAU * float(i) / 26.0 + float(i) * 0.3
				var p: Vector2 = base + Vector2(0, -70) + Vector2(cos(a), sin(a)) * (30.0 + k * 140.0) + Vector2(0, k * k * 60.0)
				var c: Color = [Color(1, 0.85, 0.3), Color(1, 0.5, 0.15), Color(0.6, 0.6, 0.65)][i % 3]
				_c.draw_circle(p, maxf(1.0, 12.0 - k * 3.0), Color(c, maxf(0.0, 1.0 - k * 0.3)))
			_c.draw_circle(base + Vector2(0, -70), maxf(0.0, 70.0 - k * 30.0), Color(1, 0.9, 0.6, maxf(0.0, 0.8 - k * 0.4)))
		_big_text("VEHICLE LOST", UI.C_RED, 4.2)
	else:
		_big_text("ORBIT REACHED", UI.C_GREEN, 4.0)


func _power(ok: bool) -> void:
	var r: Rect2 = SCREEN
	var earth: Vector2 = Vector2(r.get_center().x, r.end.y + 40.0)
	var er: float = 230.0
	# the sun on the right, the shadow on the left
	if _sun_tex != null:
		var pulse: float = 1.0 + sin(_t * 2.0) * 0.03
		_draw_fit(_sun_tex, Vector2(r.end.x - 70, r.position.y + 80), Vector2(170, 150) * pulse)
	else:
		_c.draw_circle(Vector2(r.end.x - 40, r.position.y + 70), 40.0, Color(1, 0.85, 0.4))
		_c.draw_circle(Vector2(r.end.x - 40, r.position.y + 70), 60.0, Color(1, 0.85, 0.4, 0.15))
	if _earth_tex != null:
		# the team's Earth already has its night side on the left
		_draw_fit(_earth_tex, earth, Vector2(er, er) * 2.08)
	else:
		_c.draw_circle(earth, er, Color(0.14, 0.34, 0.66))
		_c.draw_circle(earth + Vector2(-60, -40), er * 0.9, Color(0.18, 0.42, 0.78))
	_c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x * 0.45, r.size.y), Color(0, 0, 0, 0.35))
	_c.draw_string(ThemeDB.fallback_font, r.position + Vector2(30, r.size.y - 60), "EARTH'S SHADOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	# the satellite moves right to left, into the shadow
	var u: float = clampf(_t / 5.5, 0.0, 1.0)
	var a: float = lerpf(-0.35, -2.75, u)
	var pos: Vector2 = earth + Vector2(cos(a), sin(a)) * (er + 60.0)
	var in_dark: bool = pos.x < r.position.x + r.size.x * 0.45
	var battery: float = 100.0
	if in_dark:
		var dark_u: float = clampf((r.position.x + r.size.x * 0.45 - pos.x) / (r.size.x * 0.35), 0.0, 1.0)
		battery = lerpf(100.0, 0.0 if not ok else 45.0, dark_u)
	var dead: bool = not ok and battery <= 1.0
	var spin: float = 0.0
	if dead:
		spin = (_t - 4.5) * 2.0
	_satellite(pos, a + PI * 0.5 + spin, not dead)
	_gauge(r.position + Vector2(r.size.x - 260, 150), "BATTERY", battery, 15.0)
	if dead:
		_big_text("SIGNAL LOST", UI.C_RED, 4.6)
	elif ok and _t > 5.0:
		_big_text("SURVIVED THE NIGHT", UI.C_GREEN, 5.0)


func _data() -> void:
	var r: Rect2 = SCREEN
	var sat: Vector2 = Vector2(r.position.x + 200, r.position.y + 140)
	var station: Vector2 = Vector2(r.end.x - 200, r.end.y - 60)
	_satellite(sat, 0.0, true)
	if _station_tex != null:
		_draw_fit(_station_tex, station + Vector2(0, -4), Vector2(130, 90))
	else:
		_c.draw_rect(Rect2(station + Vector2(-20, -10), Vector2(40, 30)), Color(0.5, 0.52, 0.6))
		_c.draw_arc(station + Vector2(0, -24), 24.0, PI, TAU, 16, Color(0.8, 0.82, 0.9), 4.0)
	_c.draw_line(sat, station + Vector2(0, -24), Color(UI.C_ACCENT, 0.25), 6.0)
	# photos come in fast, but only a few fit down the radio link
	var made: int = int(_t * 6.0)
	var sent: int = int(_t * 3.0)
	for i in range(sent):
		var k: float = fmod(_t * 0.8 - float(i) * 0.33, 1.0)
		if k > 0.0:
			_c.draw_rect(Rect2(sat.lerp(station + Vector2(0, -24), k) - Vector2(5, 5), Vector2(10, 10)), UI.C_GREEN)
	var stored: float = clampf(float(made - sent) * 5.0, 0.0, 100.0)
	_gauge(r.position + Vector2(40, 260), "STORAGE ON BOARD", stored, -1.0, 90.0)
	_c.draw_string(ThemeDB.fallback_font, r.position + Vector2(40, 320), "Photos made: %d    sent: %d" % [made, sent], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.85))
	if stored >= 100.0:
		for i in range(8):
			var p: Vector2 = sat + Vector2(-30 + i * 9, 30 + fmod(_t * 60.0 + i * 20.0, 120.0))
			_c.draw_rect(Rect2(p, Vector2(8, 8)), Color(UI.C_RED, 0.8))
		_big_text("PHOTOS LOST", UI.C_RED, 4.0)


func _budget() -> void:
	var r: Rect2 = SCREEN
	_satellite(r.get_center() + Vector2(0, 40), 0.0, false)
	var money: float = maxf(0.0, 100.0 - _t * 26.0)
	_gauge(r.position + Vector2(40, 90), "MONEY LEFT", money, 15.0)
	if _t > 4.0:
		var k: float = clampf((_t - 4.0) * 4.0, 0.0, 1.0)
		_c.draw_set_transform(r.get_center() + Vector2(0, 30), -0.25, Vector2.ONE * lerpf(2.0, 1.0, k))
		_c.draw_rect(Rect2(-190, -40, 380, 80), Color(UI.C_RED, 0.9 * k), false, 6.0)
		_c.draw_string(UI.pixel_font(), Vector2(-170, 18), "CANCELLED", HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color(UI.C_RED, k))
		_c.draw_set_transform(Vector2.ZERO)


func _late() -> void:
	var r: Rect2 = SCREEN
	var ground_y: float = r.end.y - 40.0
	_c.draw_rect(Rect2(r.position.x, ground_y, r.size.x, 40), Color(0.12, 0.14, 0.18))
	var day: int = int(clampf(_t / 4.0, 0.0, 1.0) * 30.0) + 160
	_c.draw_string(UI.display_font(), r.position + Vector2(40, 80), "DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1))
	var climb: float = pow(maxf(0.0, _t - 3.0), 2.0) * 45.0
	_rocket(Vector2(r.get_center().x + 140, ground_y - climb), 0.0, _t > 2.8, _t - 2.8)
	# your satellite, still in its crate on a truck
	var tx: float = r.position.x + 120.0 + minf(_t, 5.0) * 30.0
	_c.draw_rect(Rect2(tx, ground_y - 50, 120, 36), Color(0.75, 0.6, 0.35))
	_c.draw_string(ThemeDB.fallback_font, Vector2(tx + 8, ground_y - 26), "YOUR SATELLITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.08, 0.05))
	_c.draw_rect(Rect2(tx - 10, ground_y - 14, 150, 12), Color(0.3, 0.32, 0.4))
	_c.draw_circle(Vector2(tx + 10, ground_y - 2), 9.0, Color(0.1, 0.1, 0.12))
	_c.draw_circle(Vector2(tx + 110, ground_y - 2), 9.0, Color(0.1, 0.1, 0.12))
	_big_text("THE ROCKET LEFT WITHOUT YOU", UI.C_RED, 4.6)


func _fault() -> void:
	var r: Rect2 = SCREEN
	var c: Vector2 = r.get_center()
	var broken: bool = _t > 3.0
	_satellite(c, 0.0 if not broken else (_t - 3.0) * 0.4, true)
	if not broken:
		for i in range(3):
			var k: float = fmod(_t + float(i) * 0.35, 1.0)
			_c.draw_arc(c + Vector2(0, -16), 20.0 + k * 90.0, -PI * 0.8, -PI * 0.2, 16, Color(UI.C_ACCENT, 1.0 - k), 2.0)
	else:
		# the loose cable sparks and the antenna drifts away
		if fmod(_t, 0.3) < 0.15:
			_c.draw_circle(c + Vector2(10, -14), 6.0, Color(1, 0.9, 0.4))
		var drift: Vector2 = Vector2(60, -40) * (_t - 3.0)
		_c.draw_line(c + Vector2(0, -16) + drift, c + Vector2(0, -46) + drift, Color(0.85, 0.85, 0.9), 3.0)
		_big_text("RADIO SILENT", UI.C_RED, 3.8)
