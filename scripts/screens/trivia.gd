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
const RocketArt = preload("res://scripts/ui/rocket_art.gd")
const TriviaPick = preload("res://scripts/core/trivia_pick.gd")

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
var _wait_label: Label = null   # the live "next round in m:ss" on the start panel


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
	_wait_label = null
	UI.clear(_body)
	_buttons = []


# ---------------------------------------------------------------- the start panel

## The start panel: a centred title, a small row of cards that say how it works (with
## little pictures and mini charts), your star dust, the rounds left today and the button.
func _show_intro() -> void:
	_clear()
	var panel: PanelContainer = UI.neon_panel(UI.C_CYAN, 24.0)
	_place(panel, Vector2(150, 96), Vector2(980, 480), _body)
	var col: VBoxContainer = UI.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var head: Label = UI.label("Earn star dust", 30, UI.C_CYAN)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var sub: Label = UI.label("Answer space questions. Spend star dust on lives and expert advice.", 16, UI.C_MUTED, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.custom_minimum_size = Vector2(900.0, 0.0)
	col.add_child(sub)
	# four small cards, each with its own little picture
	var per: int = int(_cfg.get("stardust_per_correct", 50))
	var cards: HBoxContainer = UI.hbox(14)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards)
	var items: Array = [
		["questions", "10 questions", "Rockets, missions and the people behind them"],
		["ladder", "Harder each time", "Easy first, expert last"],
		["dust", "%d star dust each" % per, "Up to %d a round" % (per * 10)],
		["days", "%d rounds a day" % int(_cfg.get("rounds_per_day", 3)), "%d minutes apart" % int(_cfg.get("cooldown_minutes", 10))],
	]
	for item in items:
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.09, 0.18, 0.9), Color(UI.C_ACCENT, 0.5), 8, 1, 10.0))
		card.custom_minimum_size = Vector2(212.0, 170.0)
		cards.add_child(card)
		var cc: VBoxContainer = UI.vbox(6)
		cc.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(cc)
		var pic: Control = Control.new()
		pic.custom_minimum_size = Vector2(190.0, 70.0)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.draw.connect(_draw_card_picture.bind(pic, str(item[0])))
		cc.add_child(pic)
		var t: Label = UI.label(str(item[1]), 16, UI.C_GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cc.add_child(t)
		var d: Label = UI.label(str(item[2]), 13, UI.C_TEXT, true)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size = Vector2(190.0, 0.0)
		cc.add_child(d)
	# your star dust and the rounds left, side by side
	var st: Dictionary = GameState.trivia_status(_cfg)
	var stats: HBoxContainer = UI.hbox(30)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stats)
	var mine: HBoxContainer = UI.hbox(8)
	stats.add_child(mine)
	mine.add_child(UI.sparkle_icon(28.0))
	mine.add_child(UI.label("You have %d star dust" % GameState.stardust, 17, Color(0.82, 0.74, 1.0)))
	stats.add_child(UI.label("Rounds left today: %d" % int(st.get("left", 0)), 17, UI.C_GOLD))
	if bool(st.get("ok", false)):
		var go: Button = UI.pixel_button("Start round  >", _start_round, 320.0, 56.0, 20, Color(0.45, 0.78, 1.0))
		UI.add_icon(go, "sparkle", UI.C_GOLD, 24.0)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(go)
	else:
		_wait_label = UI.label(str(st.get("why", "")), 22, UI.C_YELLOW, true)
		_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wait_label.custom_minimum_size = Vector2(900.0, 0.0)
		col.add_child(_wait_label)
		set_process(true)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 606), Vector2(160, 50), _body)


## The small pictures on the start cards, drawn in code: a question mark, a rising bar
## chart, a sparkle with a pile, and a row of three days.
func _draw_card_picture(c: Control, kind: String) -> void:
	var m: Vector2 = c.size * 0.5
	match kind:
		"questions":
			c.draw_circle(m, 28.0, Color(UI.C_ACCENT, 0.15))
			c.draw_arc(m, 28.0, 0.0, TAU, 40, UI.C_ACCENT, 2.5)
			c.draw_string(UI.pixel_font(), m + Vector2(-12, 14), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UI.C_CYAN)
		"ladder":
			for i in range(4):
				var h: float = 14.0 + float(i) * 13.0
				var col: Color = [UI.C_GREEN, UI.C_YELLOW, UI.C_ORANGE, UI.C_RED][i]
				c.draw_rect(Rect2(Vector2(m.x - 62.0 + float(i) * 32.0, c.size.y - h - 4.0), Vector2(26.0, h)), col)
		"dust":
			UI.draw_sparkle_at(c, m + Vector2(0, -2), 26.0, Color(0.82, 0.74, 1.0))
			for i in range(5):
				c.draw_rect(Rect2(m + Vector2(-34.0 + float(i) * 14.0, 26.0 - float(i % 2) * 6.0), Vector2(8, 8)), Color(0.82, 0.74, 1.0, 0.7))
		"days":
			for i in range(3):
				var r: Rect2 = Rect2(Vector2(m.x - 78.0 + float(i) * 54.0, 8.0), Vector2(46.0, 50.0))
				c.draw_rect(r, Color(0.03, 0.07, 0.14))
				c.draw_rect(r, Color(UI.C_ACCENT, 0.8), false, 2.0)
				c.draw_rect(Rect2(r.position, Vector2(r.size.x, 12.0)), Color(UI.C_ACCENT, 0.8))
				c.draw_circle(r.position + Vector2(r.size.x * 0.5, 34.0), 8.0, UI.C_GOLD)


## 10 questions: a few from each level of difficulty, easiest first, shuffled within a level.
## Questions you have already had are left out until you have seen every question in that
## level; then that level starts over (GameState.trivia_seen remembers, across sessions).
func _start_round() -> void:
	var per_level: Array = _cfg.get("per_round", [3, 3, 2, 2])
	var all: Array = _cfg.get("questions", [])
	_round = TriviaPick.pick_round(all, per_level, GameState.trivia_seen)
	for q in _round:
		GameState.trivia_seen[str((q as Dictionary).get("id", ""))] = true
	GameState.save_game()
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
		b.add_theme_font_size_override("font_size", UI.fs(16))
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
	if _wait_label != null:
		# waiting for the next round: count down every frame, and open when it is time
		var st: Dictionary = GameState.trivia_status(_cfg)
		if bool(st.get("ok", false)):
			_show_intro()
		else:
			_wait_label.text = str(st.get("why", ""))
		return
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
		var art: String = str(q.get("art", ""))
		if path != "" and ResourceLoader.exists(path):
			_tex = load(path)
		elif art.begins_with("rocket:"):
			# the real rocket, drawn (no free photo of it)
			_scene = RocketArt.new()
			_scene.set("rocket", art.substr(7))
			_scene.size = Vector2(140, 330)
			add_child(_scene)
		# otherwise "art" names a subject drawn in _draw (sputnik, dsky, mars_orbit)

	func _process(delta: float) -> void:
		_t += delta
		if _scene != null:
			_scene.position = size * 0.5 - _scene.size * 0.5 + Vector2(0, sin(_t * 1.2) * 6.0)
			_scene.queue_redraw()
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
		match str(q.get("art", "")):
			"":
				pass
			"sputnik":
				_draw_sputnik()
			"dsky":
				_draw_dsky()
			"mars_orbit":
				_draw_mars_orbit()
			"moon":
				_draw_moon(false)
			"earthrise":
				_draw_moon(true)
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
		elif str(q.get("art", "")) != "":
			draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), "Drawing", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))

	## Sputnik 1: a polished ball with four long antennas swept back, slowly turning, beeping.
	func _draw_sputnik() -> void:
		var c: Vector2 = size * 0.5 + Vector2(sin(_t * 0.5) * 20.0, cos(_t * 0.4) * 10.0)
		var ang: float = _t * 0.25
		for k in range(4):
			var a: float = ang + 2.5 + float(k) * 0.16 - 0.24
			var tip: Vector2 = c + Vector2(cos(a), sin(a)) * 170.0 + Vector2(0, float(k - 1.5) * 18.0)
			draw_line(c, tip, Color(0.78, 0.80, 0.85), 2.0)
		draw_circle(c, 40.0, Color(0.62, 0.64, 0.70))
		draw_circle(c + Vector2(-12, -12), 26.0, Color(0.85, 0.87, 0.92))
		draw_circle(c + Vector2(-18, -18), 8.0, Color(1, 1, 1))
		# the beep
		var k2: float = fmod(_t, 1.0)
		draw_arc(c, 50.0 + k2 * 120.0, -0.6, 0.6, 24, Color(UI.C_ACCENT, 1.0 - k2), 2.0)
		draw_string(UI.pixel_font(false), c + Vector2(70, -60), "BEEP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UI.C_ACCENT, 1.0 - k2))

	## The Apollo guidance computer's keypad (the DSKY): green number displays and keys.
	func _draw_dsky() -> void:
		var r: Rect2 = Rect2(size.x * 0.5 - 170, 30, 340, size.y - 60)
		draw_rect(r, Color(0.55, 0.56, 0.58))
		draw_rect(r, Color(0.2, 0.2, 0.22), false, 3.0)
		var disp: Rect2 = Rect2(r.position + Vector2(20, 18), Vector2(300, 130))
		draw_rect(disp, Color(0.05, 0.06, 0.05))
		var font: Font = UI.pixel_font(false)
		var labels: Array = ["PROG 63", "VERB 16  NOUN 68", "+%05d" % (int(_t * 37.0) % 99999), "+%05d" % (int(_t * 11.0 + 400.0) % 99999)]
		for i in range(labels.size()):
			draw_string(font, disp.position + Vector2(14, 28 + i * 28), str(labels[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.35, 1.0, 0.45, 0.9 if fmod(_t + float(i), 2.0) > 0.3 else 0.4))
		var keys: Array = ["VERB", "+", "7", "8", "9", "CLR", "NOUN", "-", "4", "5", "6", "PRO", "", "0", "1", "2", "3", "KEY REL", "", "", "ENTR", "RSET", "", ""]
		for i in range(18):
			var kx: float = r.position.x + 20.0 + float(i % 6) * 50.0
			var ky: float = r.position.y + 170.0 + float(i / 6) * 50.0
			draw_rect(Rect2(kx, ky, 44, 42), Color(0.12, 0.12, 0.13))
			draw_string(ThemeDB.fallback_font, Vector2(kx + 6, ky + 26), str(keys[i]), HORIZONTAL_ALIGNMENT_LEFT, 40, 11, Color(0.92, 0.92, 0.92))

	## The Moon, drawn: a grey ball with craters, lit from the left, slowly turning. With
	## earth = true, a little Earth rises over its edge (Apollo 8's view).
	func _draw_moon(earth: bool) -> void:
		var c: Vector2 = Vector2(size.x * 0.5, size.y * (1.15 if earth else 0.52))
		var r: float = size.y * (0.78 if earth else 0.34)
		draw_circle(c, r + 14.0, Color(0.85, 0.85, 0.95, 0.07))
		draw_circle(c, r, Color(0.62, 0.62, 0.66))
		draw_circle(c + Vector2(-r * 0.22, -r * 0.22), r * 0.78, Color(0.74, 0.74, 0.78))
		draw_circle(c + Vector2(r * 0.30, r * 0.20), r * 0.70, Color(0.0, 0.0, 0.0, 0.18))
		for k in range(9):
			var a: float = float(k) * 2.4 + _t * 0.05
			var rr: float = r * (0.20 + 0.55 * fposmod(float(k) * 0.37, 1.0))
			var p: Vector2 = c + Vector2(cos(a), sin(a) * 0.9) * rr * 0.9
			var cr: float = r * (0.05 + 0.04 * fposmod(float(k) * 0.61, 1.0))
			if p.distance_to(c) < r - cr:
				draw_circle(p, cr, Color(0.48, 0.48, 0.52))
				draw_arc(p, cr, PI * 0.9, PI * 1.9, 12, Color(0.85, 0.85, 0.9, 0.8), 2.0)
		if earth:
			var e: Vector2 = Vector2(size.x * 0.66, size.y * 0.30 - fmod(_t, 8.0) * 1.2)
			draw_circle(e, 34.0, Color(0.15, 0.40, 0.78))
			draw_circle(e + Vector2(-8, -6), 14.0, Color(0.28, 0.66, 0.40))
			draw_circle(e + Vector2(10, 12), 9.0, Color(0.28, 0.66, 0.40))
			draw_arc(e, 34.0, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.7), 2.0)

	## Mars, and a small orbiter dipping too low, into the glowing upper air.
	func _draw_mars_orbit() -> void:
		var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.62)
		draw_circle(c, 150.0, Color(0.72, 0.36, 0.22))
		draw_circle(c + Vector2(-30, -30), 110.0, Color(0.82, 0.46, 0.28))
		draw_arc(c, 158.0, 0.0, TAU, 64, Color(1.0, 0.6, 0.4, 0.35), 8.0)
		var a: float = -2.6 + fmod(_t * 0.4, 1.6)
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * 165.0
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.9, 0.85, 0.6))
		draw_line(p - Vector2(18, 0), p + Vector2(18, 0), Color(0.4, 0.6, 1.0), 4.0)
		draw_circle(p, 14.0, Color(1.0, 0.5, 0.2, 0.25 + 0.2 * sin(_t * 8.0)))
