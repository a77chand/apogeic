extends Control
## Launch scene: about 10 seconds, no input needed, Skip always works.
## begin_ops() is the first thing that happens, so Skip is always safe.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Sprites = preload("res://scripts/ui/sprites.gd")
const Starfield = preload("res://scripts/ui/starfield.gd")

const START_Y: float = 230.0     # where the rocket stands
const TOP_Y: float = -520.0      # off the top of the screen: reached orbit
const PAD_START: float = -720.0  # the drawn sky is 1440 px tall; its bottom half is on screen
const PAD_DROP: float = 420.0    # how far the ground falls away as the camera pulls back

var _done: bool = false
var _tween: Tween = null
var _rocket: Control = null
var _count: Label = null
var _note: Label = null
var _orbit_bg: Control = null
var _pad: Control = null
var _reached: bool = true
var _climb: float = 100.0
var _stage: String = ""           # where it failed: "climb" (never launched), "max_q", "second_stage", "separation"
var _skip: Button = null

## Error lines shown on a failure. One is picked at random each time, so failures do not
## all look the same. The reason for the failure itself is never random (see Sim.launch_risks).
const ERRORS: Dictionary = {
	"climb": ["HOLD HOLD HOLD: LAUNCH CHECKS NOT PASSED", "ERR 0x001: COMMIT CRITERIA NOT MET", "RANGE SAFETY: LAUNCH SCRUBBED", "ABORT: READINESS BELOW MINIMUM"],
	"max_q": ["ERR 0x3F2: STRUCTURAL LOAD EXCEEDED", "ALERT: VEHICLE BREAKUP AT MAX-Q", "FAULT 117: PAYLOAD MOUNT FAILURE", "TELEMETRY LOST AT T+58 s"],
	"second_stage": ["ERR 0x7A1: STAGE 2 UNDERSPEED", "FAULT 204: ENGINE SHUTDOWN, LOW THRUST", "ALERT: ORBIT VELOCITY NOT REACHED", "GUIDANCE: VELOCITY SHORTFALL"],
	"separation": ["ERR 0x0D4: DEPLOYER JAMMED", "FAULT 311: SPRING RELEASE FAILED", "ALERT: PANELS SNAGGED ON THE DOOR", "NO SEPARATION SIGNAL RECEIVED"],
}


func _ready() -> void:
	GameState.begin_ops()
	_reached = bool(GameState.launch_outcome.get("reached_orbit", true))
	_climb = float(GameState.launch_outcome.get("climb_pct", 100.0))
	_stage = str(GameState.launch_outcome.get("stage", ""))
	if not _reached and _stage == "":
		_stage = "climb"
	if ResourceLoader.exists("res://art/backgrounds/bg_launch_pad.png"):
		_pad = UI.background("res://art/backgrounds/bg_launch_pad.png")
	else:
		_pad = Sprites.make("bg_launch_pad", Vector2(1280, 1440))   # drawn: one tall, seamless sky
		_pad.position = Vector2(0, PAD_START)
	add_child(_pad)
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
	_rocket.pivot_offset = Vector2(75.0, 225.0)
	# The rocket drawn depends on the design's mass: small, medium or heavy.
	var rocket: String = "rocket_" + Sim.rocket_for_mass(GameState.level, float(GameState.launch_eval.get("mass_kg", 0.0)))
	var own: String = str((GameState.level.get("rocket", {}) as Dictionary).get("kind", ""))
	if own != "":
		rocket = own   # each mission has its own kind of rocket (see the level file)
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

	_skip = UI.button("Skip", _finish, 140.0, false)
	add_child(_skip)
	_skip.position = Vector2(1100.0, 650.0)
	_skip.size = Vector2(160.0, 52.0)

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
		_tween.tween_property(_rocket, "position:y", TOP_Y, 4.0).set_ease(Tween.EASE_IN)
		# the camera pulls away: the rocket shrinks and the ground drops out of view
		_tween.parallel().tween_property(_rocket, "scale", Vector2(0.55, 0.55), 4.0)
		_tween.parallel().tween_property(_pad, "position:y", _pad.position.y + PAD_DROP, 4.0).set_ease(Tween.EASE_IN)
		_tween.tween_property(_orbit_bg, "modulate:a", 1.0, 1.0)
		_tween.tween_callback(_open_cubesat)
		_tween.tween_interval(2.0)
	elif _stage == "climb":
		# Not enough checks passed: the engines light, sputter, and the launch is aborted on the pad.
		_tween.tween_interval(0.5)
		_tween.tween_callback(_flame_off)
		_tween.tween_interval(0.25)
		_tween.tween_callback(_flame_on_quiet)
		_tween.tween_interval(0.3)
		_tween.tween_callback(_flame_off)
		_tween.tween_callback(_shake.bind(8.0, 0.4))
		_tween.tween_callback(_failed)
	else:
		# The rocket climbs to where the problem bites (max-Q, second stage or separation).
		var peak: float = START_Y + (TOP_Y - START_Y) * (_climb / 100.0) * 0.8
		var rise: float = maxf(0.8, 4.0 * _climb / 100.0)
		var pull: float = _climb / 100.0
		_tween.tween_property(_rocket, "position:y", peak, rise).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_rocket, "scale", Vector2.ONE * (1.0 - 0.45 * pull), rise)
		_tween.parallel().tween_property(_pad, "position:y", _pad.position.y + PAD_DROP * pull * 0.8, rise).set_ease(Tween.EASE_IN)
		if _stage == "max_q":
			_tween.tween_callback(_shake.bind(5.0, 0.5))
			_tween.tween_interval(0.5)
			_tween.tween_callback(_explode)
			_tween.tween_interval(0.6)
		elif _stage == "second_stage":
			# the engine coughs and dies, and the rocket tumbles back down
			for i in range(3):
				_tween.tween_callback(_flame_off)
				_tween.tween_interval(0.15)
				_tween.tween_callback(_flame_on_quiet)
				_tween.tween_interval(0.15)
			_tween.tween_callback(_flame_off)
			_tween.tween_callback(_play.bind("fail"))
			_tween.tween_property(_rocket, "rotation", 2.4, 2.0).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_rocket, "position:y", START_Y + 300.0, 2.0).set_ease(Tween.EASE_IN)
			_tween.parallel().tween_property(_rocket, "modulate:a", 0.0, 2.0)
		else:
			# separation: orbit is reached, but the satellite stays stuck in the rocket
			_tween.tween_property(_orbit_bg, "modulate:a", 1.0, 0.8)
			_tween.tween_callback(_flame_off)
			_tween.tween_callback(_say.bind("Releasing the satellite..."))
			_tween.tween_interval(1.0)
			_tween.tween_callback(_shake.bind(4.0, 0.3))
			_tween.tween_interval(0.4)
			_tween.tween_callback(_shake.bind(4.0, 0.3))
			_tween.tween_interval(0.4)
			_tween.tween_callback(_say.bind(""))
		_tween.tween_callback(_failed)
	if not _reached:
		return   # a failure waits for the player to press "See what went wrong"
	_tween.tween_callback(_finish)


func _flame_on_quiet() -> void:
	var flame: Node = _rocket.get_node_or_null("Flame")
	if flame is AnimatedSprite2D:
		(flame as AnimatedSprite2D).visible = true
	elif flame != null:
		_set_particles(flame, true)


## Shakes the whole screen for a moment.
func _shake(strength: float, seconds: float) -> void:
	var t: Tween = create_tween()
	var steps: int = int(seconds / 0.04)
	for i in range(steps):
		var fade: float = 1.0 - float(i) / float(maxi(1, steps))
		t.tween_property(self, "position", Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * fade, 0.04)
	t.tween_property(self, "position", Vector2.ZERO, 0.04)


## The rocket blows apart: a white flash, a fireball, falling debris, a bang.
func _explode() -> void:
	GameState.play_sound("boom")
	_shake(16.0, 0.9)
	var centre: Vector2 = _rocket.position + Vector2(75.0, 200.0) * _rocket.scale
	_rocket.visible = false
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.85, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.create_tween().tween_property(flash, "color:a", 0.0, 0.6)
	var fire: CPUParticles2D = CPUParticles2D.new()
	fire.position = centre
	fire.one_shot = true
	fire.explosiveness = 0.95
	fire.amount = 140
	fire.lifetime = 1.4
	fire.spread = 180.0
	fire.gravity = Vector2(0, 40)
	fire.initial_velocity_min = 120.0
	fire.initial_velocity_max = 420.0
	fire.damping_min = 120.0
	fire.damping_max = 220.0
	fire.scale_amount_min = 8.0
	fire.scale_amount_max = 22.0
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1.0, 0.75, 0.25, 1), Color(0.9, 0.3, 0.12, 0.9), Color(0.25, 0.25, 0.28, 0.0)])
	fire.color_ramp = ramp
	add_child(fire)
	fire.emitting = true
	var debris: CPUParticles2D = CPUParticles2D.new()
	debris.position = centre
	debris.one_shot = true
	debris.explosiveness = 1.0
	debris.amount = 36
	debris.lifetime = 2.6
	debris.spread = 180.0
	debris.gravity = Vector2(0, 260)
	debris.initial_velocity_min = 140.0
	debris.initial_velocity_max = 360.0
	debris.angular_velocity_min = -400.0
	debris.angular_velocity_max = 400.0
	debris.scale_amount_min = 3.0
	debris.scale_amount_max = 7.0
	debris.color = Color(0.55, 0.58, 0.64)
	add_child(debris)
	debris.emitting = true


## The failure screen: alarm, a big MISSION FAILED, an error line, and every reason as a bullet.
func _failed() -> void:
	GameState.play_sound("error")
	var outcome: Dictionary = GameState.launch_outcome
	var red: ColorRect = ColorRect.new()
	red.color = Color(0.9, 0.05, 0.05, 0.0)
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(red)
	red.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pulse: Tween = red.create_tween().set_loops(3)
	pulse.tween_property(red, "color:a", 0.28, 0.18)
	pulse.tween_property(red, "color:a", 0.0, 0.30)
	var banner: Control = UI.result_art(false, 1000.0)
	if banner == null:
		var words: Label = UI.label("Mission failed", 72, UI.C_RED)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner = words
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	banner.position = Vector2(140.0, 70.0)
	banner.size = Vector2(1000.0, 100.0)
	if _stage == "climb":
		var abort: Label = UI.label("Launch aborted on the pad", 20, UI.C_ORANGE)
		abort.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		abort.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(abort)
		abort.position = Vector2(140.0, 146.0)
		abort.size = Vector2(1000.0, 28.0)
	banner.pivot_offset = Vector2(500.0, 50.0)
	banner.scale = Vector2(1.6, 1.6)
	banner.create_tween().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var codes: Array = ERRORS.get(_stage, ERRORS["climb"])
	var code: Label = UI.label(str(codes[randi() % codes.size()]), 18, UI.C_YELLOW)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(code)
	code.position = Vector2(140.0, 180.0)
	code.size = Vector2(1000.0, 30.0)
	# the reasons, as short bullets in a panel
	var panel: PanelContainer = UI.panel(UI.C_RED, 14.0)
	add_child(panel)
	panel.position = Vector2(240.0, 430.0)
	panel.custom_minimum_size = Vector2(800.0, 0.0)
	var col: VBoxContainer = UI.vbox(6)
	panel.add_child(col)
	var where: String = "On the launch pad" if _stage == "climb" else "At " + str(outcome.get("stage_name", "the climb"))
	col.add_child(UI.label(where, 18, UI.C_ORANGE))
	var lines: Array = []
	var ready: float = float(outcome.get("readiness_pct", 100.0))
	var needed: float = float(outcome.get("needed_pct", 0.0))
	if ready < needed - 0.01:
		lines.append("Only %d%% of the checks passed. The rocket needs %d%%." % [int(round(ready)), int(round(needed))])
	for item in outcome.get("risks", []):
		var r: Dictionary = item
		lines.append(str(r.get("text", "")))
	if lines.is_empty():
		lines.append(_failure_text())
	col.add_child(UI.bullets(lines.slice(0, 3), 15, UI.C_TEXT, 760.0, UI.C_RED))
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
	_skip.text = "See what went wrong"
	_skip.position = Vector2(960.0, 650.0)
	_skip.size = Vector2(300.0, 52.0)
	_skip.custom_minimum_size = Vector2(300.0, 52.0)


func _say(text: String) -> void:
	if _note != null:
		_note.text = text


func _count_to(text: String) -> void:
	if _count != null:
		_count.text = text
	if text != "":
		GameState.play_sound("beep")   # 3, 2, 1


func _play(id: String) -> void:
	GameState.play_sound(id)


func _flame_on() -> void:
	GameState.play_sound("go")
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
	var why: String = str(GameState.launch_outcome.get("fail_text", ""))
	if why != "":
		if why.begins_with("Failure"):
			return why
		return "The launch failed. " + why
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
