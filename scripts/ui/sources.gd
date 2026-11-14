extends Control
## "Resources and sources": where the game's facts come from and how close to real life
## they are. Opened from the menu. Reads data/sources.json.

const UI = preload("res://scripts/ui/ui.gd")
const Data = preload("res://scripts/core/data.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 20.0)
	add_child(panel)
	panel.position = Vector2(140, 40)
	panel.size = Vector2(1000, 640)
	panel.custom_minimum_size = Vector2(1000, 640)
	var col: VBoxContainer = UI.vbox(10)
	panel.add_child(col)
	var head: HBoxContainer = UI.hbox(10)
	col.add_child(head)
	var title: Label = UI.label("Resources and sources", 26, UI.C_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.button("Close", queue_free, 120.0, true))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(956, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body: VBoxContainer = UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var cfg: Dictionary = Data.load_dict("res://data/sources.json")
	body.add_child(UI.label("How close to real life is it?", 18, UI.C_TEXT))
	body.add_child(UI.bullets(cfg.get("accuracy", []), 15, UI.C_TEXT, 920.0))
	body.add_child(UI.label("Where the facts come from", 18, UI.C_TEXT))
	for item in cfg.get("sources", []):
		var s: Dictionary = item
		var card: PanelContainer = UI.panel(UI.C_DISABLED_BORDER, 10.0)
		body.add_child(card)
		var c: VBoxContainer = UI.vbox(2)
		card.add_child(c)
		var t: Label = UI.label(str(s.get("title", "")), 16, UI.C_ACCENT, true)
		t.custom_minimum_size = Vector2(900.0, 0.0)
		c.add_child(t)
		c.add_child(UI.label("%s  ·  %s" % [str(s.get("by", "")), str(s.get("where", ""))], 13, UI.C_MUTED))
		var used: Label = UI.label("Used for: " + str(s.get("used_for", "")), 14, UI.C_TEXT, true)
		used.custom_minimum_size = Vector2(900.0, 0.0)
		c.add_child(used)
	body.add_child(UI.label("Made with", 18, UI.C_TEXT))
	body.add_child(UI.bullets(cfg.get("made_with", []), 14, UI.C_MUTED, 920.0))
