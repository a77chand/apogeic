extends Control
## Orbit operations: one week every few seconds. The player manages the satellite.
## Loop, actions, event cards, and optional animations (pulse, warning light, sparks).

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Sim = preload("res://scripts/core/sim.gd")
const Data = preload("res://scripts/core/data.gd")
const EventCard = preload("res://scripts/ui/event_card.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const OrbitRing = preload("res://scripts/ui/orbit_ring.gd")

const CENTRE: Vector2 = Vector2(640.0, 372.0)
const ORBIT_A: float = 300.0     # half-width of the orbit ellipse
const ORBIT_B: float = 105.0     # half-height: a flat ellipse looks like a tilted orbit
const ORBIT_TILT: float = -0.22  # radians; tips the ellipse a little
const GROUND_POS: Vector2 = Vector2(488.0, 500.0)   # a point just inside the edge of the Earth (lower left)
const GROUND_BUBBLE: Vector2 = Vector2(372.0, 604.0) # the callout circle that shows the station up close

var _week_label: Label = null
var _battery_bar: ProgressBar = null
var _battery_label: Label = null
var _stored_label: Label = null
var _delivered_label: Label = null
var _money_label: Label = null
var _fuel_bar: ProgressBar = null
var _fuel_label: Label = null
var _log_label: Label = null
var _marker: Control = null
var _pass_btn: Button = null
var _pause_btn: Button = null

var _angle: float = -PI / 2.0
var _acc: float = 0.0
var _paused: bool = false
var _speed: float = 1.0
var _safe_on: bool = false
var _lowres_on: bool = false
var _pass_queued: bool = false
var _ending: bool = false
var _event_open: bool = false
var _pulse: AnimatedSprite2D = null
var _warning: AnimatedSprite2D = null
var _brownout: bool = false
var _space: Control = null           # holds, back to front: orbit back half, Earth, ground, orbit front half
var _ring_back: Control = null
var _ring_front: Control = null
var _sat_in_front: bool = true
var _pulse_left: float = 0.0   # 1 right after data is sent, fades to 0 (drawn rings and link)


func _ready() -> void:
	if GameState.ops.is_empty():
		GameState.begin_ops()  # e.g. opened from the stub flow
	_build()
	_refresh()
	_say("Week 0: the satellite is in orbit.")
	Tutorial.maybe_show(self, "ops")


func _ops_cfg() -> Dictionary:
	return GameState.level.get("ops", {})


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


# ---------------------------------------------------------------- layout

func _build() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	row.add_child(Player.badge(44.0))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_week_label = UI.label("", 28)
	row.add_child(_week_label)
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)

	# The space layer keeps a fixed back-to-front order: far half of the orbit, Earth, ground
	# station, near half of the orbit. The satellite is moved in between as it goes round,
	# so it passes behind the Earth and in front of it.
	_space = Control.new()
	_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_space)
	_space.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring_back = _make_ring(false)
	_space.add_child(_ring_back)
	var earth: Control = UI.picture("res://art/backgrounds/earth_large.png", Vector2(440, 440), "Earth")
	earth.position = CENTRE - Vector2(220.0, 220.0)
	earth.size = Vector2(440, 440)
	earth.custom_minimum_size = Vector2(440, 440)
	if earth.get("kind") == "earth_large":
		earth.set("spin_speed", 0.10)   # the drawn Earth turns slowly
	_space.add_child(earth)
	# The ground station is a dot on the Earth, with a circle beside it showing it up close.
	var pin: Control = Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.size = Vector2(1280, 720)
	pin.draw.connect(_draw_ground_pin.bind(pin))
	_space.add_child(pin)
	var ground: Control = UI.picture("res://art/modules/ground_station.png", Vector2(64, 64), "ground station")
	ground.position = GROUND_BUBBLE - Vector2(32, 34)
	ground.size = Vector2(64, 64)
	_space.add_child(ground)
	var ground_label: Label = UI.label("Ground station", 12, UI.C_MUTED)
	ground_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ground_label.position = GROUND_BUBBLE + Vector2(-60, 46)
	ground_label.size = Vector2(120, 18)
	_space.add_child(ground_label)
	_ring_front = _make_ring(true)
	_space.add_child(_ring_front)
	_marker = UI.picture("res://art/modules/spacecraft_marker.png", Vector2(64, 64), "satellite")
	_marker.size = Vector2(64, 64)
	_marker.custom_minimum_size = Vector2(64, 64)
	_marker.pivot_offset = Vector2(32, 32)
	_space.add_child(_marker)
	_place_satellite()

	# left panel: numbers
	var left: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(left, Vector2(20, 88), Vector2(250, 380))
	var lcol: VBoxContainer = UI.vbox(8)
	left.add_child(lcol)
	lcol.add_child(UI.label("Satellite", 20))
	lcol.add_child(UI.label("Battery", 13, UI.C_MUTED))
	_battery_bar = UI.meter(220.0)
	lcol.add_child(_battery_bar)
	_battery_label = UI.label("", 14)
	lcol.add_child(_battery_label)
	_stored_label = UI.label("", 14)
	lcol.add_child(_stored_label)
	_delivered_label = UI.label("", 14)
	lcol.add_child(_delivered_label)
	_money_label = UI.label("", 14)
	lcol.add_child(_money_label)
	lcol.add_child(UI.label("Fuel", 13, UI.C_MUTED))
	_fuel_bar = UI.meter(220.0)
	lcol.add_child(_fuel_bar)
	_fuel_label = UI.label("", 14)
	lcol.add_child(_fuel_label)

	# right panel: actions
	var right: PanelContainer = UI.panel(UI.C_BORDER, 14.0)
	_place(right, Vector2(1010, 88), Vector2(250, 420))
	var rcol: VBoxContainer = UI.vbox(8)
	right.add_child(rcol)
	rcol.add_child(UI.label("Actions", 20))
	rcol.add_child(_toggle("Safe mode", _on_safe))
	rcol.add_child(_toggle("Smaller photos", _on_lowres))
	var cost: float = float(_ops_cfg().get("extra_pass_cost_k", 10.0))
	_pass_btn = UI.button("Buy extra pass (%s)" % UI.money(cost), _on_pass, 220.0, false)
	rcol.add_child(_pass_btn)
	var speed_row: HBoxContainer = UI.hbox(6)
	rcol.add_child(speed_row)
	_pause_btn = UI.button("Pause", _on_pause, 70.0, false)
	speed_row.add_child(_pause_btn)
	speed_row.add_child(UI.button("1x", _on_speed.bind(1.0), 60.0, false))
	speed_row.add_child(UI.button("2x", _on_speed.bind(2.0), 60.0, false))

	_log_label = UI.label("", 16, UI.C_TEXT, true)
	_place(_log_label, Vector2(300, 664), Vector2(680, 40))
	_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# optional animations: each one is skipped if its frames are missing
	_pulse = _make_sprite("signal_pulse", 6, 12.0, true)
	if _pulse != null:
		_pulse.visible = false
	_warning = _make_sprite("warning_light_blink", 2, 2.0, true)
	if _warning != null:
		_warning.position = Vector2(290.0, 150.0)
		_warning.visible = false


## The station's spot on the Earth (a glowing dot), a line out to a circle, and the circle.
func _draw_ground_pin(pin: Control) -> void:
	var dot: Vector2 = GROUND_POS
	var bubble: Vector2 = GROUND_BUBBLE
	var r: float = 44.0
	pin.draw_circle(dot, 9.0, Color(UI.C_ACCENT, 0.25))
	pin.draw_circle(dot, 5.0, UI.C_ACCENT)
	var dir: Vector2 = (bubble - dot).normalized()
	pin.draw_line(dot + dir * 6.0, bubble - dir * r, Color(UI.C_ACCENT, 0.8), 2.0)
	pin.draw_circle(bubble, r, Color(0.03, 0.08, 0.17, 0.92))
	pin.draw_arc(bubble, r, 0.0, TAU, 48, Color(UI.C_ACCENT, 0.9), 2.0)


## Builds an animation from art/animations/<base>/<base>_01.png onward. Null if missing.
func _make_sprite(base: String, count: int, fps: float, loop: bool) -> AnimatedSprite2D:
	var frames: SpriteFrames = UI.frames("res://art/animations/" + base, base, count, fps, loop)
	if frames == null:
		return null
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	add_child(sprite)
	sprite.play(base)
	return sprite


## Sparks at the marker, once, when the storm damages the camera.
func _play_sparks() -> void:
	var sparks: AnimatedSprite2D = _make_sprite("sparks_burst", 6, 12.0, false)
	if sparks == null:
		return
	sparks.position = _marker.position + Vector2(32.0, 32.0)
	sparks.animation_finished.connect(sparks.queue_free)


## Signal pulse at the marker for about a second after data is sent.
func _show_pulse() -> void:
	GameState.play_sound("ping")
	_pulse_left = 1.0
	if _pulse == null:
		return
	_pulse.visible = true
	var t: Tween = create_tween()
	t.tween_interval(1.0)
	t.tween_callback(_hide_pulse)


func _hide_pulse() -> void:
	if _pulse != null:
		_pulse.visible = false


func _toggle(text: String, handler: Callable) -> Button:
	var b: Button = UI.button(text, Callable(), 220.0, false)
	b.toggle_mode = true
	b.add_theme_stylebox_override("pressed", UI.box(UI.C_HOVER, UI.C_GREEN, 16, 4))
	b.add_theme_stylebox_override("hover_pressed", UI.box(UI.C_HOVER.lightened(0.1), UI.C_GREEN, 16, 4))
	b.toggled.connect(handler)
	return b


func _make_ring(front: bool) -> Control:
	var ring: Control = OrbitRing.new()
	ring.set("centre", CENTRE)
	ring.set("radius_a", ORBIT_A)
	ring.set("radius_b", ORBIT_B)
	ring.set("tilt", ORBIT_TILT)
	ring.set("front", front)
	ring.set("ground_pos", GROUND_POS)
	ring.size = Vector2(1280, 720)
	return ring


## Puts the satellite on the orbit for the current angle. Near the viewer (sin > 0) it is
## bigger and bright and drawn over the Earth; far side it is smaller, dimmer, and hidden
## by the Earth where they overlap.
func _place_satellite() -> void:
	if _marker == null or _space == null:
		return
	var depth: float = sin(_angle)
	var local: Vector2 = Vector2(cos(_angle) * ORBIT_A, sin(_angle) * ORBIT_B).rotated(ORBIT_TILT)
	_marker.position = CENTRE + local - Vector2(32.0, 32.0)
	var near: float = (depth + 1.0) / 2.0
	_marker.scale = Vector2.ONE * (0.68 + 0.42 * near)
	var shade: float = 0.62 + 0.38 * near
	_marker.modulate = Color(shade, shade, minf(1.0, shade + 0.08), 1.0)
	var in_front: bool = depth >= 0.0
	if in_front != _sat_in_front:
		_sat_in_front = in_front
		if in_front:
			_space.move_child(_marker, _space.get_child_count() - 2)   # just below the near half
		else:
			_space.move_child(_marker, 1)                              # just above the far half, below the Earth


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		if _ring_front != null:
			_ring_front.set("pulse_left", _pulse_left)
			_ring_front.set("sat_pos", _marker.position + Vector2(32.0, 32.0))
			_ring_front.queue_redraw()
	if _pulse != null and _marker != null:
		_pulse.position = _marker.position + Vector2(32.0, 32.0)
	if _paused or _ending or _event_open or GameState.tutorial_open:
		return
	var week_seconds: float = maxf(0.5, float(_ops_cfg().get("seconds_per_week", 5.0)))
	_angle += delta * _speed * TAU / week_seconds
	_place_satellite()
	_acc += delta * _speed
	if _acc >= week_seconds:
		_acc -= week_seconds
		_run_week()


func _run_week() -> void:
	# Events first: each one is shown once, the clock waits while the card is open.
	var next_week: int = int(GameState.ops.get("week", 0)) + 1
	var list: Array = GameState.events_due("ops", next_week)
	for item in list:
		var event: Dictionary = item
		var id: String = str(event.get("id", ""))
		if GameState.events_seen.has(id):
			continue
		GameState.events_seen[id] = true
		_event_open = true
		GameState.play_sound("alert")
		var card: Control = EventCard.new()
		card.call("setup", event)
		add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var index: int = await card.chosen
		if not is_inside_tree():
			return
		var make_before: float = float(GameState.ops.get("make_mult", 1.0))
		var part_ids: Array = GameState.launch_eval.get("part_ids", [])
		var late: bool = is_instance_valid(card) and bool(card.get("timed_out"))
		var line: String = Sim.apply_ops_choice(GameState.ops, part_ids, event, index)
		var paid: float = float(card.get("advice_paid_k")) if is_instance_valid(card) else 0.0
		line = Sim.apply_late_and_advice(GameState.ops, "ops", late, paid) + line
		GameState.add_log(line)
		UI.choice_toast(self, Sim.choice_rating(event, index, part_ids), late)
		if float(GameState.ops.get("make_mult", 1.0)) < make_before - 0.0001:
			_play_sparks()
		_event_open = false
		_refresh()
	var act: Dictionary = {"safe_mode": _safe_on, "lowres": _lowres_on, "extra_pass": _pass_queued}
	var summary: Dictionary = Sim.ops_week(GameState.level, GameState.launch_eval, GameState.ops, act)
	_pass_queued = false
	_brownout = bool(summary.get("brownout", false))
	if float(summary.get("sent", 0.0)) > 0.0:
		_show_pulse()
	_refresh()
	_say("Week %d: made %d MB, sent %d MB, lost %d MB" % [
			int(summary.get("week", 0)), int(round(float(summary.get("made", 0.0)))),
			int(round(float(summary.get("sent", 0.0)))), int(round(float(summary.get("lost", 0.0))))])
	if bool(GameState.ops.get("ended", false)):
		_end_mission()


func _end_mission() -> void:
	_ending = true
	_marker.modulate = Color(0.4, 0.4, 0.45)
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.5
	add_child(timer)
	timer.timeout.connect(_on_end_timer)
	timer.start()


func _on_end_timer() -> void:
	var score: Dictionary = Sim.score_mission(GameState.level, GameState.ops, GameState.launch_results)
	GameState.record_stars(int(score.get("stars", 0)))
	GameState.record_mission_result(str(score.get("grade", "failed")), int(score.get("stars", 0)))
	GameState.go("report")


func _say(text: String) -> void:
	if _log_label != null:
		_log_label.text = text


func _refresh() -> void:
	var st: Dictionary = GameState.ops
	var cfg: Dictionary = _ops_cfg()
	_week_label.text = "Week %d of %d" % [int(st.get("week", 0)), int(cfg.get("weeks", 12))]
	var battery: float = float(st.get("battery_pct", 0.0))
	UI.set_meter(_battery_bar, battery, UI.status_for(battery > 0.0, battery < 30.0))
	_battery_label.text = "%d%%" % int(round(battery))
	_stored_label.text = "Stored data: %d of %d MB" % [int(round(float(st.get("stored_mb", 0.0)))), int(cfg.get("storage_mb", 80))]
	_delivered_label.text = "Delivered: %d of %d MB" % [int(round(float(st.get("delivered_mb", 0.0)))), int(cfg.get("goal_mb", 480))]
	_money_label.text = "Money: %s" % UI.money(float(st.get("money_k", 0.0)))
	var fuel: float = float(st.get("fuel_pct", 100.0))
	UI.set_meter(_fuel_bar, fuel, UI.status_for(fuel > 0.0, fuel < 25.0))
	_fuel_label.text = "%d%%" % int(round(fuel))
	if int(st.get("decay_week", 0)) > 0:
		_fuel_label.text += "  (the orbit decays in week %d)" % int(st.get("decay_week", 0))
	if _warning != null:
		_warning.visible = battery < 30.0 or _brownout
	_refresh_pass_button()


func _refresh_pass_button() -> void:
	var cfg: Dictionary = _ops_cfg()
	var cost: float = float(cfg.get("extra_pass_cost_k", 10.0))
	var cooldown: int = int(GameState.ops.get("cooldown", 0))
	var money: float = float(GameState.ops.get("money_k", 0.0))
	var text: String = "Buy extra pass (%s)" % UI.money(cost)
	if cooldown > 0:
		text = "Extra pass: cooldown %d" % cooldown
	elif _pass_queued:
		text = "Extra pass booked"
	_pass_btn.text = text
	_pass_btn.disabled = cooldown > 0 or _pass_queued or money < cost


# ---------------------------------------------------------------- actions

func _on_safe(pressed: bool) -> void:
	_safe_on = pressed


func _on_lowres(pressed: bool) -> void:
	_lowres_on = pressed


func _on_pass() -> void:
	_pass_queued = true
	_refresh_pass_button()


func _on_pause() -> void:
	_paused = not _paused
	if _paused:
		_pause_btn.text = "Resume"
	else:
		_pause_btn.text = "Pause"


func _on_speed(value: float) -> void:
	_speed = value
