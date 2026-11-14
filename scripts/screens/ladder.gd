extends Control
## The puzzle ladder: one step per puzzle, then the full mission.
## done = finished, open = can be played, locked = finish the step before first.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")

var _tip: Label = null


func _ready() -> void:
	_build_top_bar()
	_build_steps()
	_build_bottom()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var row: HBoxContainer = UI.hbox(16)
	bar.add_child(row)
	row.add_child(Player.badge(44.0))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UI.label("Learn one rule at a time", 28))
	var spacer2: Control = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)
	row.add_child(UI.label("Best score: %d of 3 stars" % GameState.best_stars, 16, UI.C_YELLOW))


func _build_steps() -> void:
	var holder: HBoxContainer = UI.hbox(14)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(holder, Vector2(20, 150), Vector2(1240, 360))
	var order: Array = GameState.puzzle_order()
	var all_done: bool = true
	for item in order:
		var id: String = str(item)
		var done: bool = GameState.is_puzzle_done(id)
		var open: bool = GameState.is_puzzle_open(id)
		if not done:
			all_done = false
		var pz: Dictionary = GameState.puzzles.get(id, {})
		holder.add_child(_step(str(pz.get("title", id)), str(pz.get("lesson", "")), done, open, _on_puzzle.bind(id)))
	holder.add_child(_step("Full mission", "Use every rule at once: brief, build, test, launch, operate.", false, all_done, _on_mission))


func _step(title: String, blurb: String, done: bool, open: bool, handler: Callable) -> Control:
	var border: Color = UI.C_DISABLED_BORDER
	var status: String = "Locked"
	var status_color: Color = UI.C_MUTED
	if done:
		border = UI.C_GREEN
		status = "Done"
		status_color = UI.C_GREEN
	elif open:
		border = UI.C_CYAN
		status = "Open"
		status_color = UI.C_CYAN
	var panel: PanelContainer = UI.panel(border, 14.0)
	panel.custom_minimum_size = Vector2(220.0, 300.0)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label(title, 20, UI.C_TEXT, true))
	var text: Label = UI.label(blurb, 13, UI.C_MUTED, true)
	text.custom_minimum_size = Vector2(190.0, 0.0)
	col.add_child(text)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(UI.label(status, 16, status_color))
	if open or done:
		col.add_child(UI.button("Play", handler, 190.0, open and not done))
	else:
		var locked: Button = UI.button("Locked", _on_locked, 190.0, false)
		UI.look_locked(locked)
		col.add_child(locked)
	return panel


func _build_bottom() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(false))
	_place(bar, Vector2(0, 662), Vector2(1280, 58))
	_tip = UI.label("Finish each puzzle to unlock the next one.", 15)
	bar.add_child(_tip)
	_place(UI.button("Back", _on_back, 160.0, false), Vector2(20, 590), Vector2(160, 52))


func _on_puzzle(id: String) -> void:
	GameState.go("puzzle_" + id)


func _on_mission() -> void:
	GameState.go("missions")


func _on_locked() -> void:
	_tip.text = "Finish the step before this one."


func _on_back() -> void:
	GameState.go("title")
