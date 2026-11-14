extends Control
## A small astronaut figure: the astronaut picture tinted with the suit colour, and a round
## mission patch with the player's initial. Build one with Player.figure() or Player.badge().
## If the art file is missing it draws a simple figure instead, so nothing breaks.

const TEXTURE_PATH: String = "res://art/ui/ui_astronaut.png"

var _height: float = 48.0
var _suit: Color = Color(0.92, 0.94, 0.98)
var _patch: Color = Color(0.25, 0.82, 0.88)
var _initial: String = ""
var _tex: Texture2D = null


func setup(height: float, suit: Color, patch: Color, initial: String) -> void:
	_height = height
	_suit = suit
	_patch = patch
	_initial = initial.strip_edges().left(1).to_upper()
	custom_minimum_size = Vector2(height * 0.64, height)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tex == null and ResourceLoader.exists(TEXTURE_PATH):
		_tex = load(TEXTURE_PATH)
	queue_redraw()


func _draw() -> void:
	var h: float = _height
	if _tex != null:
		# the art has empty margins left and right, so draw only the middle half
		var tw: float = float(_tex.get_width())
		var th: float = float(_tex.get_height())
		draw_texture_rect_region(_tex, Rect2(0.0, 0.0, h * 0.5, h), Rect2(tw * 0.25, 0.0, tw * 0.5, th), _suit)
	else:
		draw_circle(Vector2(h * 0.25, h * 0.2), h * 0.17, Color(0.1, 0.07, 0.16))
		draw_rect(Rect2(h * 0.08, h * 0.35, h * 0.34, h * 0.45), _suit)
		draw_rect(Rect2(h * 0.1, h * 0.8, h * 0.12, h * 0.2), _suit.darkened(0.3))
		draw_rect(Rect2(h * 0.28, h * 0.8, h * 0.12, h * 0.2), _suit.darkened(0.3))
	# the mission patch
	var centre: Vector2 = Vector2(h * 0.5, h * 0.78)
	var radius: float = h * 0.17
	draw_circle(centre, radius + 2.0, Color(0.02, 0.05, 0.12))
	draw_circle(centre, radius, _patch)
	if _initial != "":
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(8, int(h * 0.22))
		var text_size: Vector2 = font.get_string_size(_initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(font, centre + Vector2(-text_size.x * 0.5, font_size * 0.36), _initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.02, 0.05, 0.12))
