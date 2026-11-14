extends RefCounted
## The player's astronaut: the choices on offer, and ready-made pieces to show it on any screen.
## Use it through a preload:  const Player = preload("res://scripts/ui/player.gd")
##
##   bar_row.add_child(Player.badge(44.0))      # small figure plus name and title
##   add_child(Player.figure(300.0))            # the figure alone
## Suits are real suit styles from different decades and countries; patches are emblems.
## The choices themselves are saved in GameState (player_name, player_title, avatar_suit, avatar_patch).

const UI = preload("res://scripts/ui/ui.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

const TITLES: Array = ["Commander", "Engineer", "Pilot", "Scientist", "Cadet"]

const SUITS: Array = Avatar.SUITS        # [name, fabric colour, details, caption]
const PATCHES: Array = Avatar.PATCHES    # [name, background colour, emblem]


static func suit_color(index: int) -> Color:
	var entry: Array = SUITS[clampi(index, 0, SUITS.size() - 1)]
	return entry[1]


static func patch_color(index: int) -> Color:
	var entry: Array = PATCHES[clampi(index, 0, PATCHES.size() - 1)]
	return entry[1]


## An astronaut with explicit choices (the profile screen uses this for its live preview).
static func figure_for(height: float, suit_index: int, patch_index: int, name_text: String) -> Control:
	var fig: Control = Avatar.new()
	fig.call("setup", height, suit_index, patch_index, name_text)
	return fig


## The player's own astronaut, read from GameState.
static func figure(height: float) -> Control:
	return figure_for(height, GameState.avatar_suit, GameState.avatar_patch, GameState.player_name)


const BADGE_WIDTH: float = 210.0
const C_NAME: Color = Color(1.0, 1.0, 1.0)
const C_RANK: Color = Color(0.98, 0.80, 0.33)   # gold, like a rank on a flight suit


## A name plate: a small figure, the title in gold capitals and the name in white, on a
## solid dark plate with a coloured edge. It has a fixed width and cuts off long names,
## so it never pushes into the box next to it. Fits a 72 px top bar at height 44.
static func badge(height: float = 44.0) -> Control:
	var plate: PanelContainer = PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = UI.box(Color(0.02, 0.05, 0.11, 0.96), Color(patch_color(GameState.avatar_patch), 0.9), 8, 1, 4.0)
	sb.border_width_left = 4
	sb.corner_detail = 1
	sb.content_margin_left = 8.0
	sb.content_margin_right = 10.0
	plate.add_theme_stylebox_override("panel", sb)
	var width: float = BADGE_WIDTH * clampf(height / 44.0, 0.8, 1.3)
	plate.custom_minimum_size = Vector2(width, 0.0)
	var row: HBoxContainer = UI.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	row.add_child(figure(height))
	var col: VBoxContainer = UI.vbox(-2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title_text: String = GameState.player_title
	if title_text == "":
		title_text = "Astronaut"
	var rank: Label = UI.label(title_text.to_upper(), 11, C_RANK)
	rank.add_theme_constant_override("outline_size", 1)
	rank.clip_text = true
	col.add_child(rank)
	var name_text: String = GameState.player_name.strip_edges()
	if name_text == "":
		name_text = "Cadet"
	var name_label: Label = UI.label(name_text, 16, C_NAME)
	name_label.add_theme_font_override("font", UI.display_font())
	name_label.add_theme_font_size_override("font_size", 19 if name_text.length() <= 10 else 16)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(width - height - 30.0, 0.0)
	col.add_child(name_label)
	return plate
