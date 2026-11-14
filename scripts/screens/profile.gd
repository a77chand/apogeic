extends Control
## Create your astronaut: a name, a title, a real suit from one era of spaceflight, and a mission patch.
## The choices are saved, and show up on the other screens (see player.gd).
## Opened from the title screen: the first time you press Play, and from "Customise astronaut".

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

var _name_text: String = ""
var _title: String = "Commander"
var _suit: int = 0
var _patch: int = 0
var _preview_holder: VBoxContainer = null
var _preview: Control = null
var _caption: Label = null
var _rank_label: Label = null
var _colour_note: Label = null
var _name_edit: LineEdit = null
var _title_buttons: Dictionary = {}   # title -> Button
var _suit_buttons: Array = []
var _patch_buttons: Array = []
var _done_btn: Button = null


func _ready() -> void:
	_name_text = GameState.player_name
	if GameState.player_title != "":
		_title = GameState.player_title
	_suit = GameState.avatar_suit
	_patch = GameState.avatar_patch
	_build_top_bar()
	_build_preview()
	_build_choices()
	_build_buttons()
	_refresh()


func _place(node: Control, pos: Vector2, sz: Vector2) -> void:
	add_child(node)
	node.position = pos
	node.custom_minimum_size = sz
	node.size = sz


func _build_top_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.bar_style(true))
	_place(bar, Vector2(0, 0), Vector2(1280, 72))
	var title: Label = UI.label("Create your astronaut", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)


func _build_preview() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 16.0)
	_place(panel, Vector2(20, 88), Vector2(380, 512))
	_preview_holder = UI.vbox(12)
	_preview_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(_preview_holder)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.add_child(centre)
	_preview = Player.figure_for(330.0, _suit, _patch, _name_text)
	centre.add_child(_preview)
	# a name plate under the figure: title in gold capitals, name in white, cut off if too long
	var plate: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = UI.box(Color(0.02, 0.05, 0.11, 0.96), Color(UI.C_ACCENT, 0.6), 8, 1, 10.0)
	sb.corner_detail = 1
	plate.add_theme_stylebox_override("panel", sb)
	plate.custom_minimum_size = Vector2(320.0, 0.0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_holder.add_child(plate)
	var pcol: VBoxContainer = UI.vbox(0)
	plate.add_child(pcol)
	_rank_label = UI.label("", 13, Player.C_RANK)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pcol.add_child(_rank_label)
	_caption = UI.label("", 16, Player.C_NAME)
	_caption.add_theme_font_override("font", UI.display_font())
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.clip_text = true
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.custom_minimum_size = Vector2(296.0, 0.0)
	pcol.add_child(_caption)
	_colour_note = UI.label("", 13, UI.C_MUTED)
	_colour_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_holder.add_child(_colour_note)


func _build_choices() -> void:
	var panel: PanelContainer = UI.panel(UI.C_BORDER, 20.0)
	_place(panel, Vector2(420, 88), Vector2(840, 512))
	var col: VBoxContainer = UI.vbox(14)
	panel.add_child(col)
	col.add_child(UI.label("Your name", 18))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Type your name"
	_name_edit.max_length = 14
	_name_edit.text = _name_text
	_name_edit.custom_minimum_size = Vector2(360.0, 44.0)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.text_changed.connect(_on_name)
	col.add_child(_name_edit)
	col.add_child(UI.label("Your title", 18))
	var title_row: HBoxContainer = UI.hbox(10)
	col.add_child(title_row)
	for item in Player.TITLES:
		var t: String = str(item)
		var b: Button = UI.button(t, _on_title.bind(t), 140.0, false)
		b.custom_minimum_size = Vector2(140.0, 44.0)
		title_row.add_child(b)
		_title_buttons[t] = b
	col.add_child(UI.label("Suit: real suits from each era", 18))
	var suit_row: HBoxContainer = UI.hbox(10)
	col.add_child(suit_row)
	for i in range(Player.SUITS.size()):
		var entry: Array = Player.SUITS[i]
		var b: Button = _swatch(str(entry[0]), _on_suit.bind(i), suit_row)
		b.custom_minimum_size = Vector2(66.0, 84.0)
		var mini: Control = Player.figure_for(78.0, i, 0, "")
		mini.position = Vector2(8.0, 3.0)
		b.add_child(mini)
		_suit_buttons.append(b)
	col.add_child(UI.label("Mission patch", 18))
	var patch_row: HBoxContainer = UI.hbox(14)
	col.add_child(patch_row)
	for i in range(Player.PATCHES.size()):
		var entry: Array = Player.PATCHES[i]
		var b: Button = _swatch(str(entry[0]), _on_patch.bind(i), patch_row)
		b.draw.connect(_draw_emblem.bind(b, str(entry[2])))
		_patch_buttons.append(b)


## A round colour chip with its name underneath. The chosen one gets a white ring and a tick.
func _swatch(colour_name: String, on_press: Callable, row: HBoxContainer) -> Button:
	var cell: VBoxContainer = UI.vbox(4)
	row.add_child(cell)
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(54.0, 54.0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = colour_name
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(on_press)
	b.draw.connect(_draw_tick.bind(b))
	cell.add_child(b)
	var l: Label = UI.label(colour_name, 12, UI.C_MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(66.0, 0.0)
	cell.add_child(l)
	b.set_meta("name_label", l)
	return b


func _draw_emblem(b: Button, kind: String) -> void:
	var bg: Color = Player.patch_color(_patch_buttons.find(b))
	Avatar.draw_emblem(b, kind, b.size * 0.5, minf(b.size.x, b.size.y) * 0.36, Color(1, 1, 1, 0.92), bg)


func _draw_tick(b: Button) -> void:
	if not bool(b.get_meta("chosen", false)):
		return
	var c: Vector2 = b.size * 0.5
	var dark: Color = Color(0.02, 0.05, 0.12)
	b.draw_polyline(PackedVector2Array([c + Vector2(-9, 0), c + Vector2(-3, 7), c + Vector2(10, -7)]), dark, 4.0, true)


func _build_buttons() -> void:
	var back: Button = UI.button("Back", _on_back, 160.0, false)
	_place(back, Vector2(20, 616), Vector2(160, 52))
	_done_btn = UI.button("Done", _on_done, 220.0, true)
	_place(_done_btn, Vector2(1040, 616), Vector2(220, 52))


func _on_name(text: String) -> void:
	_name_text = text
	_refresh()


func _on_title(title: String) -> void:
	_title = title
	GameState.play_sound("click")
	_refresh()


func _on_suit(index: int) -> void:
	_suit = index
	GameState.play_sound("click")
	_refresh()


func _on_patch(index: int) -> void:
	_patch = index
	GameState.play_sound("click")
	_refresh()


func _style_choice(b: Button, selected: bool) -> void:
	var fill: Color = UI.C_PANEL
	var border: Color = UI.C_BORDER
	if selected:
		fill = UI.C_HOVER
		border = UI.C_CYAN
	b.add_theme_stylebox_override("normal", UI.box(fill, border))
	b.add_theme_stylebox_override("hover", UI.box(fill.lightened(0.1), UI.C_CYAN))
	b.add_theme_stylebox_override("pressed", UI.box(UI.C_DEEP, UI.C_CYAN))


func _style_swatch(b: Button, color: Color, selected: bool) -> void:
	var normal: StyleBoxFlat = UI.box(color, Color(color.darkened(0.45), 1.0), 27, 2, 0.0)
	normal.anti_aliasing = true
	var hover: StyleBoxFlat = UI.box(color.lightened(0.12), Color(1, 1, 1, 0.6), 27, 2, 0.0)
	hover.shadow_color = Color(color, 0.45)
	hover.shadow_size = 6
	if selected:
		normal = UI.box(color, Color(1, 1, 1), 27, 4, 0.0)
		normal.shadow_color = Color(color, 0.7)
		normal.shadow_size = 10
		hover = normal
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", normal)
	b.set_meta("chosen", selected)
	b.queue_redraw()
	var l: Label = b.get_meta("name_label", null)
	if l != null:
		l.add_theme_color_override("font_color", UI.C_TEXT if selected else UI.C_MUTED)


## A suit button: a dark tile with the small figure in it; the chosen one gets a cyan edge.
func _style_suit(b: Button, selected: bool) -> void:
	var normal: StyleBoxFlat = UI.box(Color(0.03, 0.07, 0.14), Color(UI.C_CYAN, 1.0) if selected else Color(UI.C_BORDER, 0.5), 8, 3 if selected else 1, 0.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", UI.box(Color(0.06, 0.12, 0.22), UI.C_CYAN, 8, 2, 0.0))
	b.add_theme_stylebox_override("pressed", normal)
	b.set_meta("chosen", false)
	var l: Label = b.get_meta("name_label", null)
	if l != null:
		l.add_theme_color_override("font_color", UI.C_TEXT if selected else UI.C_MUTED)


func _refresh() -> void:
	for key in _title_buttons.keys():
		_style_choice(_title_buttons[key], str(key) == _title)
	for i in range(_suit_buttons.size()):
		_style_suit(_suit_buttons[i], i == _suit)
	for i in range(_patch_buttons.size()):
		_style_swatch(_patch_buttons[i], Player.patch_color(i), i == _patch)
		_patch_buttons[i].set_meta("chosen", false)   # the white ring shows the choice; no tick over the emblem
	_preview.call("setup", 330.0, _suit, _patch, _name_text)
	var shown: String = _name_text.strip_edges()
	if shown == "":
		shown = "Your name"
	_rank_label.text = _title.to_upper()
	_caption.text = shown
	_colour_note.text = "%s suit  ·  %s patch" % [str((Player.SUITS[_suit] as Array)[3]), str((Player.PATCHES[_patch] as Array)[0])]
	_done_btn.disabled = _name_text.strip_edges() == ""


func _on_done() -> void:
	GameState.set_profile(_name_text, _title, _suit, _patch)
	GameState.go(GameState.profile_next)


func _on_back() -> void:
	GameState.go("title")
