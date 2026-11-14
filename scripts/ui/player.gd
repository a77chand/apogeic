extends RefCounted
## The player's astronaut: the choices on offer, and ready-made pieces to show it on any screen.
## Use it through a preload:  const Player = preload("res://scripts/ui/player.gd")
##
##   bar_row.add_child(Player.badge(44.0))      # small figure plus name and title
##   add_child(Player.figure(300.0))            # the figure alone
## The choices themselves are saved in GameState (player_name, player_title, avatar_suit, avatar_patch).

const UI = preload("res://scripts/ui/ui.gd")
const Avatar = preload("res://scripts/ui/avatar.gd")

const TITLES: Array = ["Commander", "Engineer", "Pilot", "Scientist", "Cadet"]

const SUITS: Array = [
	["White", Color(0.95, 0.96, 0.99)],
	["Orange", Color(0.98, 0.62, 0.24)],
	["Sky blue", Color(0.45, 0.75, 0.98)],
	["Mint", Color(0.50, 0.88, 0.66)],
	["Rose", Color(0.97, 0.55, 0.68)],
	["Violet", Color(0.70, 0.58, 0.96)],
	["Gold", Color(0.97, 0.82, 0.38)],
	["Slate", Color(0.62, 0.68, 0.78)],
]

const PATCHES: Array = [
	["Cyan", Color(0.25, 0.82, 0.88)],
	["Red", Color(0.90, 0.28, 0.30)],
	["Green", Color(0.25, 0.73, 0.31)],
	["Yellow", Color(0.95, 0.79, 0.30)],
	["Purple", Color(0.62, 0.35, 0.85)],
	["Blue", Color(0.31, 0.53, 0.84)],
]


static func suit_color(index: int) -> Color:
	var entry: Array = SUITS[clampi(index, 0, SUITS.size() - 1)]
	return entry[1]


static func patch_color(index: int) -> Color:
	var entry: Array = PATCHES[clampi(index, 0, PATCHES.size() - 1)]
	return entry[1]


## An astronaut with explicit choices (the profile screen uses this for its live preview).
static func figure_for(height: float, suit_index: int, patch_index: int, name_text: String) -> Control:
	var fig: Control = Avatar.new()
	fig.call("setup", height, suit_color(suit_index), patch_color(patch_index), name_text)
	return fig


## The player's own astronaut, read from GameState.
static func figure(height: float) -> Control:
	return figure_for(height, GameState.avatar_suit, GameState.avatar_patch, GameState.player_name)


## A small figure with the name and title beside it. Fits a 72 px top bar at height 44.
static func badge(height: float = 44.0) -> Control:
	var row: HBoxContainer = UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(figure(height))
	var col: VBoxContainer = UI.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_text: String = GameState.player_name.strip_edges()
	if name_text == "":
		name_text = "Cadet"
	col.add_child(UI.label(name_text, 16, UI.C_TEXT))
	var title_text: String = GameState.player_title
	if title_text == "":
		title_text = "Astronaut"
	col.add_child(UI.label(title_text, 12, UI.C_MUTED))
	row.add_child(col)
	return row
