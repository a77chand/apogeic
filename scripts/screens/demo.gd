extends Control
## Judge demo: what the game is, in a few lines, and one button for each highlight. It turns
## on GameState.demo_mode, which opens every mission, puzzle and challenge for this session
## only (nothing is saved, and it is off again next time the game starts).

const UI = preload("res://scripts/ui/ui.gd")

## [title, one line, button text, where it goes]
const TOUR: Array = [
	["1  Learn by failing", "Puzzle 1: pack a satellite, press Launch it, and watch what happens when it is too heavy.", "Try Puzzle 1", "puzzle_mass"],
	["2  A real decision", "Mission 10, Mars Climate Orbiter: one choice is what the real team did, units and all.", "Fly this mission", "level11"],
	["3  The NASA problem", "Robots at the Moon's south pole: pick sensors, plan routes, time the moving shadows.", "Open the problem", "truck"],
	["4  Space trivia", "10 questions with NASA photos; right answers earn star dust.", "Play a round", "trivia"],
]


func _ready() -> void:
	GameState.demo_mode = true
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	add_child(bar)
	bar.size = Vector2(1280, 72)
	var title: Label = UI.label("Judge demo", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var intro: Label = UI.label("AP0GEIC 11 teaches how real space missions are designed by letting players make the same trade-offs engineers make, and see what goes wrong. Its 20 missions are based on real spaceflights from around the world, and its NASA problem is a real challenge for Artemis: robots driving themselves near the Moon's south pole. Everything is unlocked for this demo.", 16, UI.C_TEXT, true)
	intro.custom_minimum_size = Vector2(1180.0, 0.0)
	add_child(intro)
	intro.position = Vector2(50, 90)
	for i in range(TOUR.size()):
		var t: Array = TOUR[i]
		var panel: PanelContainer = UI.neon_panel(UI.C_CYAN, 16.0)
		add_child(panel)
		panel.position = Vector2(50 + (i % 2) * 600, 200 + (i / 2) * 200)
		panel.custom_minimum_size = Vector2(570, 180)
		var col: VBoxContainer = UI.vbox(8)
		panel.add_child(col)
		col.add_child(UI.label(str(t[0]), 20, UI.C_GOLD))
		var l: Label = UI.label(str(t[1]), 15, UI.C_TEXT, true)
		l.custom_minimum_size = Vector2(520.0, 0.0)
		col.add_child(l)
		col.add_child(UI.button(str(t[2]), _go.bind(str(t[3])), 240.0, true))
	var back: Button = UI.button("Back to home", _on_back, 200.0, false)
	add_child(back)
	back.position = Vector2(50, 620)
	var all: Button = UI.button("All missions (unlocked)", _go.bind("missions"), 300.0, false)
	add_child(all)
	all.position = Vector2(930, 620)


func _go(where: String) -> void:
	if where.begins_with("level"):
		GameState.set_mission(where)
		GameState.go("briefing")
	else:
		GameState.go(where)


func _on_back() -> void:
	GameState.go("title")
