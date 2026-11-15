extends Control
## Space trivia for star dust. A round is 10 questions that get harder (picked at random
## from 40 in data/trivia.json), 20 seconds each, 50 star dust per right answer. Up to 3
## rounds a day, 10 minutes apart. Each question has a picture (a real NASA photo, or a
## drawn scene) that plays a short animation while you think; the clock does not wait for it.
## After each answer the game says why it was right or wrong.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Data = preload("res://scripts/core/data.gd")
const Sprites = preload("res://scripts/ui/sprites.gd")

var _cfg: Dictionary = {}
var _round: Array = []
var _i: int = 0
var _correct: int = 0
var _left: float = 0.0
var _answered: bool = true
var _body: Control = null
var _timer_bar: ProgressBar = null
var _timer_label: Label = null
var _buttons: Array = []
var _explain: Label = null
var _next_btn: Button = null
var _score_label: Label = null
var _art: Control = null


func _ready() -> void:
	_cfg = Data.load_dict("res://data/trivia.json")
	_build_top_bar()
	_body = Control.new()
	add_child(_body)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_intro()


func _place(node: Control, pos: Vector2, sz: Vector2, parent: Node = null) -> void:
	(parent if parent != null else self).add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Space trivia", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(title, Vector2(440, 0), Vector2(400, 72))
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(40.0, 14.0)
	var row: HBoxContainer = UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	_place(row, Vector2(980, 16), Vector2(280, 40))
	row.add_child(UI.sparkle_icon(26.0))
	_score_label = UI.label("", 16, Color(0.82, 0.74, 1.0))
	_score_label.add_theme_font_override("font", UI.pixel_font(false))
	row.add_child(_score_label)
	_refresh_score()


func _refresh_score() -> void:
	_score_label.text = "%d STAR DUST" % GameState.stardust


func _clear() -> void:
	set_process(false)
	UI.clear(_body)
	_buttons = []


# ---------------------------------------------------------------- the start panel

func _show_intro() -> void:
	_clear()
	var panel: PanelContainer = UI.neon_panel(UI.C_CYAN, 26.0)
	_place(panel, Vector2(290, 120), Vector2(700, 420), _body)
	var col: VBoxContainer = UI.vbox(14)
	panel.add_child(col)
	col.add_child(UI.label("Earn star dust", 26, UI.C_CYAN))
	var per: int = int(_cfg.get("stardust_per_correct", 50))
	col.add_child(UI.bullets([
		"10 questions on rockets, missions and the people behind them",
		"%d seconds each. They get harder as you go" % int(_cfg.get("seconds", 20)),
		"%d star dust for every right answer (up to %d a round)" % [per, per * 10],
		"Up to %d rounds a day, %d minutes apart" % [int(_cfg.get("rounds_per_day", 3)), int(_cfg.get("cooldown_minutes", 10))],
	], 16, UI.C_TEXT, 640.0))
	var st: Dictionary = GameState.trivia_status(_cfg)
	var info: Label = UI.label("Rounds left today: %d" % int(st.get("left", 0)), 15, UI.C_GOLD)
	col.add_child(info)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	if bool(st.get("ok", false)):
		var go: Button = UI.pixel_button("Start round  >", _start_round, 320.0, 56.0, 20, Color(0.45, 0.78, 1.0))
		UI.add_icon(go, "sparkle", UI.C_GOLD, 24.0)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(go)
	else:
		var why: Label = UI.label(str(st.get("why", "")), 20, UI.C_YELLOW, true)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.custom_minimum_size = Vector2(640.0, 0.0)
		col.add_child(why)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 606), Vector2(160, 50), _body)


## 10 questions: a few from each level of difficulty, easiest first, shuffled within a level.
func _start_round() -> void:
	var per_level: Array = _cfg.get("per_round", [3, 3, 2, 2])
	var all: Array = _cfg.get("questions", [])
	_round = []
	for level in range(per_level.size()):
		var pool: Array = all.filter(func(q: Variant) -> bool: return int((q as Dictionary).get("difficulty", 1)) == level + 1)
		pool.shuffle()
		for k in range(mini(int(per_level[level]), pool.size())):
			_round.append(pool[k])
	_i = 0
	_correct = 0
	_show_question()


# ---------------------------------------------------------------- a question

func _show_question() -> void:
	_clear()
	var q: Dictionary = _round[_i]
	var head: Label = UI.label("Question %d of %d  ·  %s" % [_i + 1, _round.size(), ["Easy", "Medium", "Hard", "Expert"][clampi(int(q.get("difficulty", 1)) - 1, 0, 3)]], 14, UI.C_MUTED)
	_place(head, Vector2(40, 88), Vector2(600, 24), _body)
	_timer_bar = UI.meter(1200.0)
	_place(_timer_bar, Vector2(40, 116), Vector2(1200, 10), _body)
	_timer_label = UI.label("", 13, UI.C_MUTED)
	_place(_timer_label, Vector2(1140, 88), Vector2(100, 24), _body)
	# the picture, with its little animation, on the left
	var frame: PanelContainer = UI.neon_panel(UI.C_ACCENT, 10.0)
	_place(frame, Vector2(40, 140), Vector2(560, 400), _body)
	_art = TriviaArt.new()
	_art.set("q", q)
	_art.custom_minimum_size = Vector2(536, 370)
	frame.add_child(_art)
	# the question and four answers on the right
	var qlabel: Label = UI.label(str(q.get("question", "")), 22, UI.C_TEXT, true)
	qlabel.custom_minimum_size = Vector2(620.0, 0.0)
	_place(qlabel, Vector2(630, 140), Vector2(620, 80), _body)
	var choices: Array = q.get("choices", [])
	for k in range(choices.size()):
		var b: Button = UI.button(str(choices[k]), _on_answer.bind(k), 620.0, false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 16)
		_place(b, Vector2(630, 232 + k * 64), Vector2(620, 54), _body)
		_buttons.append(b)
	_explain = UI.label("", 15, UI.C_TEXT, true)
	_explain.custom_minimum_size = Vector2(1200.0, 0.0)
	_place(_explain, Vector2(40, 552), Vector2(1200, 50), _body)
	_next_btn = UI.button("Next  >", _on_next, 200.0, true)
	_place(_next_btn, Vector2(1060, 606), Vector2(200, 50), _body)
	_next_btn.visible = false
	_left = float(_cfg.get("seconds", 20))
	_answered = false
	set_process(true)


func _process(delta: float) -> void:
	if _answered:
		return
	_left -= delta
	var total: float = float(_cfg.get("seconds", 20))
	UI.set_meter(_timer_bar, _left / total * 100.0, "green" if _left > total * 0.5 else ("yellow" if _left > 5.0 else "red"))
	_timer_label.text = "%d s" % int(ceil(maxf(0.0, _left)))
	if _left <= 0.0:
		_on_answer(-1)


func _on_answer(k: int) -> void:
	if _answered:
		return
	_answered = true
	var q: Dictionary = _round[_i]
	var right: int = int(q.get("answer", 0))
	for j in range(_buttons.size()):
		var b: Button = _buttons[j]
		b.disabled = true
		if j == right:
			b.add_theme_stylebox_override("disabled", UI.box(Color(UI.C_GREEN, 0.25), UI.C_GREEN, 8, 2, 10.0))
			b.add_theme_color_override("font_disabled_color", UI.C_TEXT)
		elif j == k:
			b.add_theme_stylebox_override("disabled", UI.box(Color(UI.C_RED, 0.22), UI.C_RED, 8, 2, 10.0))
			b.add_theme_color_override("font_disabled_color", UI.C_TEXT)
	var per: int = int(_cfg.get("stardust_per_correct", 50))
	if k == right:
		_correct += 1
		GameState.play_sound("chime")
		_explain.text = "Right! +%d star dust. %s" % [per, str(q.get("explain", ""))]
		_explain.add_theme_color_override("font_color", UI.C_GREEN)
	else:
		GameState.play_sound("fail")
		var lead: String = "Time's up." if k < 0 else "Not quite."
		_explain.text = "%s The answer is %s. %s" % [lead, str((q.get("choices", []) as Array)[right]), str(q.get("explain", ""))]
		_explain.add_theme_color_override("font_color", UI.C_YELLOW)
	_next_btn.visible = true
	_next_btn.text = "Next  >" if _i + 1 < _round.size() else "Finish"


func _on_next() -> void:
	_i += 1
	if _i < _round.size():
		_show_question()
	else:
		_show_end()


func _show_end() -> void:
	_clear()
	var earned: int = _correct * int(_cfg.get("stardust_per_correct", 50))
	GameState.finish_trivia_round(earned)
	_refresh_score()
	GameState.play_sound("fanfare" if _correct >= 7 else "chime")
	var panel: PanelContainer = UI.neon_panel(UI.C_GOLD, 26.0)
	_place(panel, Vector2(340, 150), Vector2(600, 360), _body)
	var col: VBoxContainer = UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var t: Label = UI.label("%d of %d right" % [_correct, _round.size()], 30, UI.C_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var row: HBoxContainer = UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UI.sparkle_icon(34.0))
	row.add_child(UI.label("+%d star dust" % earned, 24, Color(0.82, 0.74, 1.0)))
	var st: Dictionary = GameState.trivia_status(_cfg)
	var more: Label = UI.label("Rounds left today: %d. %s" % [int(st.get("left", 0)), str(st.get("why", ""))], 15, UI.C_MUTED, true)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.custom_minimum_size = Vector2(540.0, 0.0)
	col.add_child(more)
	_place(UI.button("Back to missions", _on_back, 240.0, true), Vector2(1020, 606), Vector2(240, 50), _body)


func _on_back() -> void:
	GameState.go("missions" if GameState.all_puzzles_done() else "title")


## The picture for a question: a real NASA photo slowly zooming and drifting (or a drawn
## scene), with a small looping animation on top. It runs on its own clock.
class TriviaArt:
	extends Control
	var q: Dictionary = {}
	var _t: float = 0.0
	var _tex: Texture2D = null
	var _scene: Control = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		var path: String = str(q.get("image", ""))
		if path != "" and ResourceLoader.exists(path):
			_tex = load(path)
		else:
			var kind: String = {"earth": "earth_large", "mars": "earth_large", "moon": "earth_large", "cubesat": "cubesat_3u", "rocket": "rocket_medium", "code": "spacecraft_marker"}.get(str(q.get("scene", "earth")), "earth_large")
			_scene = Sprites.make(kind, Vector2(220, 220))
			if str(q.get("scene", "")) == "mars":
				_scene.modulate = Color(1.0, 0.55, 0.35)
			elif str(q.get("scene", "")) == "moon":
				_scene.modulate = Color(0.75, 0.75, 0.78)
			add_child(_scene)

	func _process(delta: float) -> void:
		_t += delta
		if _scene != null:
			_scene.position = size * 0.5 - _scene.size * 0.5 + Vector2(0, sin(_t * 1.2) * 6.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06))
		if _tex != null:
			# slow zoom and drift, so the photo feels alive
			var tsz: Vector2 = Vector2(_tex.get_width(), _tex.get_height())
			var fit: float = maxf(size.x / tsz.x, size.y / tsz.y) * (1.04 + 0.06 * (0.5 + 0.5 * sin(_t * 0.35)))
			var draw_size: Vector2 = tsz * fit
			var off: Vector2 = (size - draw_size) * 0.5 + Vector2(sin(_t * 0.27) * 12.0, cos(_t * 0.21) * 8.0)
			draw_texture_rect(_tex, Rect2(off, draw_size), false)
		match str(q.get("anim", "twinkle")):
			"launch":
				for i in range(16):
					var k: float = fmod(_t * 0.6 + float(i) / 16.0, 1.0)
					var p: Vector2 = Vector2(size.x * (0.2 + 0.6 * fmod(float(i) * 0.37, 1.0)), size.y * (1.0 - k))
					draw_circle(p, 2.0 + 3.0 * (1.0 - k), Color(1.0, 0.7, 0.3, 0.6 * (1.0 - k)))
			"orbit":
				var c: Vector2 = size * 0.5
				var pts: PackedVector2Array = PackedVector2Array()
				for i in range(65):
					var a: float = TAU * float(i) / 64.0
					pts.append(c + Vector2(cos(a) * size.x * 0.38, sin(a) * size.y * 0.16).rotated(-0.25))
				draw_polyline(pts, Color(UI.C_ACCENT, 0.5), 1.5, true)
				var sa: float = _t * 1.4
				draw_circle(c + Vector2(cos(sa) * size.x * 0.38, sin(sa) * size.y * 0.16).rotated(-0.25), 5.0, Color(1, 1, 1))
			"drift":
				pass
			_:
				for i in range(24):
					var p: Vector2 = Vector2(fmod(float(i) * 97.0, size.x), fmod(float(i) * 53.0, size.y))
					var a: float = 0.3 + 0.7 * absf(sin(_t * 2.0 + float(i)))
					draw_circle(p, 1.5, Color(1, 1, 1, a))
		# a thin scan line, like a monitor
		var y: float = fmod(_t * 80.0, size.y)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UI.C_ACCENT, 0.12), 2.0)
		if _tex != null:
			draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), "Image: NASA", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.7))
