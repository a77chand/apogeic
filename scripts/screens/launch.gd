extends Control
## Launch scene: about 10 seconds, no input needed, Skip always works.
## begin_ops() is the first thing that happens, so Skip is always safe.

const UI = preload("res://scripts/ui/ui.gd")
const Sim = preload("res://scripts/core/sim.gd")

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
	add_child(UI.background("res://art/backgrounds/bg_launch_pad.png"))
	_orbit_bg = UI.background("res://art/backgrounds/bg_earth_orbit.png")
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
	_rocket.add_child(pic)
	var frames: SpriteFrames = UI.frames("res://art/animations/exhaust_flame", "exhaust_flame", 6, 12.0, true)
	if frames != null:
		var flame: AnimatedSprite2D = AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.position = Vector2(75.0, 480.0)
		flame.visible = false
		flame.name = "Flame"
		_rocket.add_child(flame)

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


func _flame_on() -> void:
	var flame: Node = _rocket.get_node_or_null("Flame")
	if flame != null:
		var sprite: AnimatedSprite2D = flame
		sprite.visible = true
		sprite.play("exhaust_flame")


func _flame_off() -> void:
	var flame: Node = _rocket.get_node_or_null("Flame")
	if flame != null:
		var sprite: AnimatedSprite2D = flame
		sprite.visible = false


func _failure_text() -> String:
	return "The launch failed. Only %d%% of the checks passed (needs %d%%), so the satellite never reached orbit." % [
			int(round(float(GameState.launch_outcome.get("readiness_pct", 0.0)))),
			int(round(float(GameState.launch_outcome.get("needed_pct", 0.0))))]


func _open_cubesat() -> void:
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
