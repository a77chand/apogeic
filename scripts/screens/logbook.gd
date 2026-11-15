extends Control
## The logbook: what you have learned. Each training puzzle you finish adds its lesson, and
## each mission you earn a star on adds the real mission's story and lesson, next to how
## you did. It shows the learning the game is built around, in one list.

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")


func _ready() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	add_child(bar)
	bar.size = Vector2(1280, 72)
	var title: Label = UI.label("Logbook", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)
	var badge: Control = Player.badge(44.0)
	add_child(badge)
	badge.position = Vector2(40.0, 14.0)
	var learned: int = 0
	var total: int = 0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.position = Vector2(40, 120)
	scroll.size = Vector2(1200, 470)
	var col: VBoxContainer = UI.vbox(8)
	col.custom_minimum_size = Vector2(1180, 0)
	scroll.add_child(col)
	col.add_child(UI.label("Training", 20, UI.C_CYAN))
	for item in GameState.puzzle_order():
		var id: String = str(item)
		var pz: Dictionary = GameState.puzzles.get(id, {})
		var done: bool = GameState.is_puzzle_done(id)
		total += 1
		if done:
			learned += 1
		col.add_child(_row(str(pz.get("title", id)), str(pz.get("lesson", "")) if done else "Finish this puzzle to add its lesson.", "", done, -1))
	col.add_child(UI.label("Missions: you, and the real thing", 20, UI.C_CYAN))
	var ids: Array = GameState.mission_ids()
	for i in range(ids.size()):
		var id: String = str(ids[i])
		var info: Dictionary = GameState.mission_info(id)
		var b: Dictionary = info.get("based_on", {})
		var stars: int = GameState.stars_for(id)
		total += 1
		if stars > 0:
			learned += 1
		var real: String = "%s (%s, %d): %s" % [str(b.get("mission", "")), str(b.get("country", "")), int(b.get("year", 0)), str(b.get("outcome", ""))]
		var text: String = "Lesson: %s   Real mission: %s" % [str(b.get("lesson", "")), real] if stars > 0 else "Earn a star to add this mission's real story and lesson."
		col.add_child(_row("%02d  %s" % [i + 1, str(info.get("name", id))], text, "", stars > 0, stars))
	var head: Label = UI.label("Ideas learned: %d of %d" % [learned, total], 18, UI.C_GOLD)
	add_child(head)
	head.position = Vector2(40, 84)
	var back: Button = UI.button("Back", _on_back, 160.0, false)
	add_child(back)
	back.position = Vector2(40, 606)


func _row(name: String, text: String, _extra: String, done: bool, stars: int) -> Control:
	var row: HBoxContainer = UI.hbox(14)
	var left: VBoxContainer = UI.vbox(2)
	left.custom_minimum_size = Vector2(260, 0)
	row.add_child(left)
	left.add_child(UI.label(name, 15, UI.C_TEXT if done else UI.C_MUTED))
	if stars >= 0:
		left.add_child(UI.star_row(stars, 16.0))
	var t: Label = UI.label(text, 14, UI.C_TEXT if done else UI.C_MUTED, true)
	t.custom_minimum_size = Vector2(900, 0)
	row.add_child(t)
	return row


func _on_back() -> void:
	GameState.go("missions" if GameState.all_puzzles_done() else "title")
