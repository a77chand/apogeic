extends Control
## Create your astronaut: a name, a title, a suit colour and a patch colour.
## The choices are saved, and show up on the other screens (see player.gd).
## Opened from the title screen: the first time you press Play, and from "Customise astronaut".

const UI = preload("res://scripts/ui/ui.gd")
const Player = preload("res://scripts/ui/player.gd")

var _name_text: String = ""
var _title: String = "Commander"
var _suit: int = 0
var _patch: int = 0
var _preview_holder: VBoxContainer = null
var _preview: Control = null
var _caption: Label = null
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
	_preview = Player.figure_for(380.0, _suit, _patch, _name_text)
	centre.add_child(_preview)
	_caption = UI.label("", 22, UI.C_CYAN)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_holder.add_child(_caption)


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
	col.add_child(UI.label("Suit colour", 18))
	var suit_row: HBoxContainer = UI.hbox(10)
	col.add_child(suit_row)
	for i in range(Player.SUITS.size()):
		var entry: Array = Player.SUITS[i]
		var b: Button = _swatch(str(entry[0]), _on_suit.bind(i))
		suit_row.add_child(b)
		_suit_buttons.append(b)
	col.add_child(UI.label("Mission patch colour", 18))
	var patch_row: HBoxContainer = UI.hbox(10)
	col.add_child(patch_row)
	for i in range(Player.PATCHES.size()):
		var entry: Array = Player.PATCHES[i]
		var b: Button = _swatch(str(entry[0]), _on_patch.bind(i))
		patch_row.add_child(b)
		_patch_buttons.append(b)
	var hint: Label = UI.label("Your name and astronaut appear in the top bar, the briefing and the mission report.", 14, UI.C_MUTED, true)
	hint.custom_minimum_size = Vector2(780.0, 0.0)
	col.add_child(hint)


func _swatch(tip: String, on_press: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(52.0, 52.0)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(on_press)
	return b


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
	var border: Color = UI.C_OUTLINE
	var width: int = 2
	if selected:
		border = Color(1, 1, 1)
		width = 4
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, UI.box(color, border, 26, width, 0.0))


func _refresh() -> void:
	for key in _title_buttons.keys():
		_style_choice(_title_buttons[key], str(key) == _title)
	for i in range(_suit_buttons.size()):
		_style_swatch(_suit_buttons[i], Player.suit_color(i), i == _suit)
	for i in range(_patch_buttons.size()):
		_style_swatch(_patch_buttons[i], Player.patch_color(i), i == _patch)
	_preview.call("setup", 380.0, Player.suit_color(_suit), Player.patch_color(_patch), _name_text)
	var shown: String = _name_text.strip_edges()
	if shown == "":
		shown = "Your name"
	_caption.text = "%s %s" % [_title, shown]
	_done_btn.disabled = _name_text.strip_edges() == ""


func _on_done() -> void:
	GameState.set_profile(_name_text, _title, _suit, _patch)
	GameState.go(GameState.profile_next)


func _on_back() -> void:
	GameState.go("title")
