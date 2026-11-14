extends Control
## How to play: the whole game on one screen, as short bullet points.
## Opened from the title screen and the menu.

const UI = preload("res://scripts/ui/ui.gd")
const Chrome = preload("res://scripts/ui/chrome.gd")

## [title, colour, bullets]
const STEPS: Array = [
	["Train", Color(0.62, 0.55, 0.96), ["4 short puzzles", "One idea each: mass, power, data, time", "Optional, but they teach the rules"]],
	["Brief", Color(0.36, 0.86, 0.95), ["Read the goal", "Note the limits: mass, money, deadline"]],
	["Build", Color(0.36, 0.76, 0.48), ["Fit parts to the satellite", "Watch the six bars turn green", "The clock runs: every day costs money"]],
	["Test", Color(0.95, 0.79, 0.30), ["Every check is tested", "Fix problems, or launch anyway and take the risk"]],
	["Launch", Color(0.95, 0.55, 0.16), ["Heavy or flawed rockets can fail", "Max-Q, second stage or separation"]],
	["Fly", Color(0.45, 0.75, 0.98), ["Run the satellite week by week", "Decide fast when events pop up", "Watch battery, storage and fuel"]],
	["Report", Color(0.97, 0.55, 0.68), ["Up to 3 stars", "See exactly why it went right or wrong", "Fix my satellite keeps your parts"]],
]


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _ready() -> void:
	add_child(Chrome.top_bar("How to play", []))
	add_child(Chrome.tip_bar("Open the menu on the left edge any time for sound, text size and sources."))
	# the mission flow as a row of cards joined by arrows
	var x: float = 20.0
	var w: float = 166.0
	for i in range(STEPS.size()):
		var step: Array = STEPS[i]
		var card: PanelContainer = UI.panel(step[1], 10.0)
		_place(card, Vector2(x, 96), Vector2(w, 250))
		var col: VBoxContainer = UI.vbox(6)
		card.add_child(col)
		var num: Label = UI.label("%d" % (i + 1), 30, step[1])
		col.add_child(num)
		col.add_child(UI.label(str(step[0]), 20, UI.C_TEXT))
		col.add_child(UI.bullets(step[2], 13, UI.C_TEXT, w - 22.0, step[1]))
		if i < STEPS.size() - 1:
			var arrow: Label = UI.label(">", 26, UI.C_ACCENT)
			_place(arrow, Vector2(x + w - 2.0, 196), Vector2(16, 40))
		x += w + 12.0
	# which button to press
	var left: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(left, Vector2(20, 366), Vector2(610, 220))
	var lcol: VBoxContainer = UI.vbox(10)
	left.add_child(lcol)
	lcol.add_child(UI.label("Which button do I press?", 20))
	lcol.add_child(UI.bullets([
		"Play: the full run. Do the 4 training puzzles first, then the missions.",
		"Skip to the missions: the main game, for when you already know the rules.",
		"Training puzzles: practise one idea at a time, any time.",
		"Missions unlock in order. Each one adds a new problem to solve.",
	], 15, UI.C_TEXT, 570.0))
	var right: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(right, Vector2(650, 366), Vector2(610, 220))
	var rcol: VBoxContainer = UI.vbox(10)
	right.add_child(rcol)
	rcol.add_child(UI.label("Like a real mission team", 20))
	rcol.add_child(UI.bullets([
		"Be quick: the build clock costs money every day.",
		"Be precise: removing a fitted part costs rework time and money.",
		"Event cards have a timer. If it runs out, the safe default is picked.",
		"Every failure has a reason you can find in the report.",
	], 15, UI.C_TEXT, 570.0))
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 600), Vector2(160, 52))
	_place(UI.button("Play", _on_play, 220.0, true), Vector2(1040, 600), Vector2(220, 52))


func _on_back() -> void:
	GameState.go("title")


func _on_play() -> void:
	GameState.profile_next = "ladder"
	GameState.go("ladder" if GameState.has_profile() else "profile")
