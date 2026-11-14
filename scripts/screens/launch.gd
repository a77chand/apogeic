extends Control
## Launch scene: about 10 seconds, no input needed, Skip always works.
## begin_ops() is the first thing that happens, so Skip is always safe.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Sprites = preload("res://scripts/ui/sprites.gd")
const Starfield = preload("res://scripts/ui/starfield.gd")

const START_Y: float = 230.0     # where the rocket stands
const TOP_Y: float = -520.0      # off the top of the screen: reached orbit

var _done: bool = false
var _tween: Tween = null
var _rocket: Control = null
var _count: Label = null
var _note: Label = null
var _orbit_bg: Control = null
var _reached: bool = true
var _climb: float = 100.0


func _ready() -> void:
	GameState.begin_ops()
	_reached = bool(GameState.launch_outcome.get("reached_orbit", true))
	_climb = float(GameState.launch_outcome.get("climb_pct", 100.0))
	if ResourceLoader.exists("res://art/backgrounds/bg_launch_pad.png"):
		add_child(UI.background("res://art/backgrounds/bg_launch_pad.png"))
	else:
		add_child(Sprites.make("bg_launch_pad", Vector2(1280, 720)))   # drawn sky, ground and tower
	if ResourceLoader.exists("res://art/backgrounds/bg_earth_orbit.png"):
		_orbit_bg = UI.background("res://art/backgrounds/bg_earth_orbit.png")
	else:
		_orbit_bg = Control.new()   # drawn: stars with the curve of the Earth below
		_orbit_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stars: Control = Starfield.new()
		_orbit_bg.add_child(stars)
		stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var limb: Control = Sprites.make("bg_earth_orbit", Vector2(1280, 720))
		_orbit_bg.add_child(limb)
	_orbit_bg.modulate = Color(1, 1, 1, 0)
	add_child(_orbit_bg)

	_rocket = Control.new()
	_rocket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rocket)
	_rocket.position = Vector2(565.0, 230.0)
	_rocket.size = Vector2(150.0, 450.0)
	# The rocket drawn depends on the design's mass: small, medium or heavy.
	var rocket: String = "rocket_" + Sim.rocket_for_mass(GameState.level, float(GameState.launch_eval.get("mass_kg", 0.0)))
	var pic: Control = UI.picture("res://art/modules/%s.png" % rocket, Vector2(150, 450), rocket)
	var frames: SpriteFrames = UI.frames("res://art/animations/exhaust_flame", "exhaust_flame", 6, 12.0, true)
	if frames != null:
		var flame: AnimatedSprite2D = AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.position = Vector2(75.0, 480.0)
		flame.visible = false
		flame.name = "Flame"
		_rocket.add_child(flame)
	else:
		_rocket.add_child(_make_flame_fx())   # added before the rocket, so it is drawn behind it
	_rocket.add_child(pic)

	_count = UI.label("", 96, UI.C_TEXT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	_count.position = Vector2(440.0, 90.0)
	_count.size = Vector2(400.0, 130.0)

	_note = UI.label("", 24, UI.C_ORANGE)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.position = Vector2(240.0, 590.0)
	_note.size = Vector2(800.0, 100.0)

	var skip: Button = UI.button("Skip", _finish, 140.0, false)
	add_child(skip)
	skip.position = Vector2(1120.0, 650.0)
	skip.size = Vector2(140.0, 52.0)

	_run_sequence()


func _run_sequence() -> void:
	_tween = create_tween()
	if bool(GameState.ops.get("slipped", false)):
		_tween.tween_callback(_say.bind("You missed your slot. Rebooking cost $90k."))
		_tween.tween_interval(2.5)
		_tween.tween_callback(_say.bind(""))
	for n in [3, 2, 1]:
		_tween.tween_callback(_count_to.bind(str(n)))
		_tween.tween_interval(1.0)
	_tween.tween_callback(_count_to.bind(""))
	_tween.tween_callback(_flame_on)
	if _reached:
		_tween.tween_property(_rocket, "position:y", TOP_Y, 4.0)
		_tween.tween_property(_orbit_bg, "modulate:a", 1.0, 1.0)
		_tween.tween_callback(_open_cubesat)
		_tween.tween_interval(2.0)
	else:
		# The climb height comes from the readiness number: more checks passed, higher it gets.
		var peak: float = START_Y + (TOP_Y - START_Y) * (_climb / 100.0) * 0.8
		var rise: float = maxf(0.8, 4.0 * _climb / 100.0)
		_tween.tween_property(_rocket, "position:y", peak, rise)
		_tween.tween_callback(_flame_off)
		_tween.tween_callback(_play.bind("fail"))
		_tween.tween_callback(_say.bind(_failure_text()))
		_tween.tween_property(_rocket, "position:y", START_Y + 120.0, 2.5)
		_tween.parallel().tween_property(_rocket, "modulate:a", 0.25, 2.5)
		_tween.tween_interval(2.5)
	_tween.tween_callback(_finish)


func _say(text: String) -> void:
	if _note != null:
		_note.text = text


func _count_to(text: String) -> void:
	if _count != null:
		_count.text = text


func _play(id: String) -> void:
	GameState.play_sound(id)


func _flame_on() -> void:
	GameState.play_sound("rumble")
	var flame: Node = _rocket.get_node_or_null("Flame")
	if flame is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = flame
		sprite.visible = true
		sprite.play("exhaust_flame")
	elif flame != null:
		_set_particles(flame, true)


func _flame_off() -> void:
	var flame: Node = _rocket.get_node_or_null("Flame")
	if flame is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = flame
		sprite.visible = false
	elif flame != null:
		_set_particles(flame, false)


func _set_particles(fx: Node, on: bool) -> void:
	for child in fx.get_children():
		if child is CPUParticles2D:
			var p: CPUParticles2D = child
			p.emitting = on


## A flame (yellow core fading to red) and a grey smoke trail, as particles. They are
## built in code and leave a trail behind the moving rocket (local_coords is off).
func _make_flame_fx() -> Node2D:
	var fx: Node2D = Node2D.new()
	fx.name = "Flame"
	fx.position = Vector2(75.0, 392.0)   # the engine bell of the drawn rocket
	var smoke: CPUParticles2D = CPUParticles2D.new()
	smoke.emitting = false
	smoke.amount = 40
	smoke.lifetime = 1.8
	smoke.local_coords = false
	smoke.direction = Vector2(0, 1)
	smoke.spread = 25.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 40.0
	smoke.initial_velocity_max = 90.0
	smoke.scale_amount_min = 9.0
	smoke.scale_amount_max = 18.0
	var smoke_ramp: Gradient = Gradient.new()
	smoke_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	smoke_ramp.colors = PackedColorArray([Color(0.84, 0.86, 0.9, 0.55), Color(0.84, 0.86, 0.9, 0.0)])
	smoke.color_ramp = smoke_ramp
	fx.add_child(smoke)
	var fire: CPUParticles2D = CPUParticles2D.new()
	fire.emitting = false
	fire.amount = 70
	fire.lifetime = 0.55
	fire.local_coords = false
	fire.direction = Vector2(0, 1)
	fire.spread = 12.0
	fire.gravity = Vector2.ZERO
	fire.initial_velocity_min = 140.0
	fire.initial_velocity_max = 230.0
	fire.scale_amount_min = 5.0
	fire.scale_amount_max = 11.0
	var fire_ramp: Gradient = Gradient.new()
	fire_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	fire_ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.77, 1.0), Color(0.96, 0.78, 0.26, 1.0), Color(0.95, 0.55, 0.16, 0.9), Color(0.88, 0.29, 0.29, 0.0)])
	fire.color_ramp = fire_ramp
	fx.add_child(fire)
	return fx


func _failure_text() -> String:
	return "The launch failed. Only %d%% of the checks passed (needs %d%%), so the satellite never reached orbit." % [
			int(round(float(GameState.launch_outcome.get("readiness_pct", 0.0)))),
			int(round(float(GameState.launch_outcome.get("needed_pct", 0.0))))]


func _open_cubesat() -> void:
	GameState.play_sound("chime")
	_rocket.visible = false
	_say("Satellite released")
	var frames: SpriteFrames = UI.frames("res://art/animations/cubesat_open", "cubesat_open", 4, 4.0, false)
	if frames == null:
		return
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.position = Vector2(640.0, 360.0)
	add_child(sprite)
	sprite.play("cubesat_open")


func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null:
		_tween.kill()
	if _reached:
		GameState.go("ops")
	else:
		GameState.go("report")  # no operations phase: the satellite never worked
