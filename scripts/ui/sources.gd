extends Control
## "Resources and sources": where the game's facts come from and how close to real life
## they are, with a formal citation and a link for each. Opened from the menu. Reads
## data/sources.json, and the based_on block of every mission.

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
	var accessed: String = str(cfg.get("accessed", ""))
	body.add_child(UI.label("Where the facts come from", 18, UI.C_TEXT))
	for item in cfg.get("sources", []):
		var src: Dictionary = item
		body.add_child(_card(src, "Used for: " + str(src.get("used_for", "")), accessed))
	# the NASA problem's own evidence (from truck.json), each with how strong it is
	var listed: Array = cfg.get("sources", []).map(func(x: Variant) -> String: return str((x as Dictionary).get("url", "")))
	var truck: Dictionary = Data.load_dict("res://data/truck.json")
	var extra: Array = (truck.get("evidence", []) as Array).filter(func(e: Variant) -> bool: return not listed.has(str((e as Dictionary).get("url", ""))))
	if not extra.is_empty():
		body.add_child(UI.label("The NASA problem: sensor evidence", 18, UI.C_TEXT))
		for item in extra:
			var e: Dictionary = item
			var src: Dictionary = {"title": str(e.get("title", "")), "cite": "Kind of evidence: " + str(e.get("kind", "")), "url": str(e.get("url", ""))}
			body.add_child(_card(src, "Supports: " + str(e.get("supports", "")), accessed))
	body.add_child(UI.label("The real missions behind the 20 levels", 18, UI.C_TEXT))
	for id in Data.MISSIONS:
		var level: Dictionary = Data.load_level(str(id))
		var b: Dictionary = level.get("based_on", {})
		if b.is_empty():
			continue
		var src: Dictionary = {"title": "%s (%s, %d)" % [str(b.get("mission", "")), str(b.get("agency", "")), int(b.get("year", 0))],
				"cite": str(b.get("source", "")), "url": str(b.get("url", ""))}
		body.add_child(_card(src, "Level \"%s\": %s" % [str(level.get("name", "")), str(b.get("story", ""))], accessed))
	body.add_child(UI.label("Made with", 18, UI.C_TEXT))
	for item in cfg.get("made_with", []):
		var m: Dictionary = item if typeof(item) == TYPE_DICTIONARY else {"text": str(item)}
		# one under the other, both wrapping, so nothing runs off the page at large text size
		var made: Label = UI.label("•  " + str(m.get("text", "")), 14, UI.C_MUTED, true)
		made.custom_minimum_size = Vector2(900.0, 0.0)
		body.add_child(made)
		if str(m.get("url", "")) != "":
			body.add_child(_link(str(m.get("url", ""))))


## One source as a card: title, a formal citation, what it is used for, and a link.
func _card(src: Dictionary, used_for: String, accessed: String) -> Control:
	var card: PanelContainer = UI.panel(UI.C_DISABLED_BORDER, 10.0)
	var c: VBoxContainer = UI.vbox(2)
	card.add_child(c)
	var t: Label = UI.label(str(src.get("title", "")), 16, UI.C_ACCENT, true)
	t.custom_minimum_size = Vector2(900.0, 0.0)
	c.add_child(t)
	var cite: String = str(src.get("cite", ""))
	if cite == "":
		# author (year). Title. Where. Accessed date.
		cite = "%s (%s). %s. %s." % [str(src.get("author", src.get("by", ""))), str(src.get("year", "n.d.")), str(src.get("title", "")), str(src.get("where", ""))]
	if accessed != "" and str(src.get("url", "")) != "":
		cite += " Accessed %s." % accessed
	var cl: Label = UI.label(cite, 13, UI.C_MUTED, true)
	cl.custom_minimum_size = Vector2(900.0, 0.0)
	c.add_child(cl)
	var used: Label = UI.label(used_for, 14, UI.C_TEXT, true)
	used.custom_minimum_size = Vector2(900.0, 0.0)
	c.add_child(used)
	if str(src.get("url", "")) != "":
		c.add_child(_link(str(src.get("url", ""))))
	return card


## A clickable web link that wraps onto the next line when it is too long for the page.
func _link(url: String) -> RichTextLabel:
	var l: RichTextLabel = RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY   # a URL has no spaces, so break anywhere
	l.custom_minimum_size = Vector2(900.0, 0.0)
	l.add_theme_font_size_override("normal_font_size", UI.fs(13))
	l.add_theme_color_override("default_color", UI.C_ACCENT)
	l.text = "[url=%s]%s[/url]" % [url, url]
	l.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return l
