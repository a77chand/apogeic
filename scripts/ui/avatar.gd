extends Control
## A small astronaut figure: the astronaut picture in a real suit style from a decade of
## spaceflight (see SUITS), and a round mission patch with the player's chosen emblem.
## Build one with Player.figure() or Player.badge(). If the art file is missing it draws a
## simple figure instead, so nothing breaks.
##
## The suit is not a tint over the whole picture: the base fabric colour is only changed
## for suits that really were that colour (silver Mercury, orange launch suits, the dark
## Artemis suit), and each era adds its own details (stripes, cuffs, bands) on top.
##
## celebrate() makes the figure jump and give a thumbs up (used for a 3-star mission).

## Real suits from different decades and countries: [name, fabric colour, details, caption].
const SUITS: Array = [
	["Apollo", Color(1, 1, 1), "apollo", "NASA A7L, 1969"],
	["Mercury", Color(0.80, 0.85, 0.92), "mercury", "NASA Mercury, 1961"],
	["Vostok", Color(0.98, 0.58, 0.28), "vostok", "USSR SK-1, 1961"],
	["Sokol", Color(1, 1, 1), "sokol", "USSR/Russia Sokol, 1973 on"],
	["Shuttle", Color(0.99, 0.56, 0.22), "aces", "NASA ACES, 1994"],
	["ISS EMU", Color(1, 1, 1), "emu", "NASA EMU spacewalk suit"],
	["Feitian", Color(1, 1, 1), "feitian", "China Feitian, 2008"],
	["Artemis", Color(0.42, 0.43, 0.48), "axemu", "Axiom AxEMU, 2023"],
]

## Mission patch emblems: [name, background colour, emblem].
const PATCHES: Array = [
	["Orbit", Color(0.10, 0.36, 0.62), "orbit"],
	["Rocket", Color(0.62, 0.16, 0.20), "rocket"],
	["Moon", Color(0.20, 0.20, 0.36), "moon"],
	["Star", Color(0.12, 0.45, 0.42), "star"],
	["Ringed planet", Color(0.48, 0.30, 0.62), "planet"],
	["Comet", Color(0.62, 0.42, 0.10), "comet"],
]


## Draws a patch emblem in white, centred, about r in radius. Used by the patch on the suit
## and by the patch picker on the profile screen.
static func draw_emblem(ci: CanvasItem, kind: String, c: Vector2, r: float, col: Color, bg: Color) -> void:
	match kind:
		"orbit":
			ci.draw_circle(c, r * 0.32, col)
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(33):
				var a: float = TAU * float(i) / 32.0
				pts.append(c + Vector2(cos(a) * r * 0.85, sin(a) * r * 0.32).rotated(-0.4))
			ci.draw_polyline(pts, col, maxf(1.0, r * 0.08), true)
			ci.draw_circle(c + Vector2(r * 0.78, 0).rotated(-0.4), r * 0.1, col)
		"rocket":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.25, -r * 0.4), c + Vector2(r * 0.25, r * 0.45), c + Vector2(-r * 0.25, r * 0.45), c + Vector2(-r * 0.25, -r * 0.4)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, r * 0.1), c + Vector2(-r * 0.55, r * 0.6), c + Vector2(-r * 0.25, r * 0.45)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.25, r * 0.1), c + Vector2(r * 0.55, r * 0.6), c + Vector2(r * 0.25, r * 0.45)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, r * 0.5), c + Vector2(0, r * 0.9), c + Vector2(r * 0.15, r * 0.5)]), Color(1.0, 0.7, 0.3, col.a))
		"moon":
			ci.draw_circle(c, r * 0.72, col)
			ci.draw_circle(c + Vector2(r * 0.34, -r * 0.18), r * 0.6, bg)
		"star":
			var star: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var rr: float = r * (0.85 if i % 2 == 0 else 0.36)
				var a: float = -PI * 0.5 + PI * float(i) / 5.0
				star.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(star, col)
		"planet":
			ci.draw_circle(c, r * 0.48, col)
			var ring: PackedVector2Array = PackedVector2Array()
			for i in range(33):
				var a: float = TAU * float(i) / 32.0
				ring.append(c + Vector2(cos(a) * r * 0.9, sin(a) * r * 0.24).rotated(-0.3))
			ci.draw_polyline(ring, col, maxf(1.0, r * 0.08), true)
		"comet":
			ci.draw_circle(c + Vector2(r * 0.35, -r * 0.35), r * 0.28, col)
			for k in range(3):
				var off: Vector2 = Vector2(-r * 0.1, r * 0.1) * float(k - 1)
				ci.draw_line(c + Vector2(r * 0.2, -r * 0.2) + off, c + Vector2(-r * 0.75, r * 0.75) + off * 1.5, Color(col, col.a * (0.9 - 0.25 * k)), maxf(1.0, r * 0.1))
const TEXTURE_PATH: String = "res://art/ui/ui_astronaut.png"

var _height: float = 48.0
var _suit: int = 0
var _patch: int = 0
var _initial: String = ""
var _tex: Texture2D = null
var _cheer_t: float = -1.0


func setup(height: float, suit_index: int, patch_index: int, initial: String) -> void:
	_height = height
	_suit = suit_index
	_patch = patch_index
	_initial = initial.strip_edges().left(1).to_upper()
	custom_minimum_size = Vector2(height * 0.64, height)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tex == null and ResourceLoader.exists(TEXTURE_PATH):
		_tex = load(TEXTURE_PATH)
	queue_redraw()


## Jump and thumbs up, over and over, until the figure is freed.
func celebrate() -> void:
	_cheer_t = 0.0


func _process(delta: float) -> void:
	if _cheer_t >= 0.0:
		_cheer_t += delta
		queue_redraw()


## A point on the 256 x 256 astronaut picture, in this control's coordinates.
## Only the middle half of the picture (x 64 to 192) is drawn.
func _t(x: float, y: float) -> Vector2:
	return Vector2((x - 64.0) / 128.0 * _height * 0.5, y / 256.0 * _height)


func _box(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	var a: Vector2 = _t(x0, y0)
	var b: Vector2 = _t(x1, y1)
	draw_rect(Rect2(a, b - a), c)


func _draw() -> void:
	var h: float = _height
	var jump: float = 0.0
	if _cheer_t >= 0.0:
		jump = -absf(sin(_cheer_t * 5.0)) * h * 0.08
	draw_set_transform(Vector2(0.0, jump))
	var era: Array = SUITS[clampi(_suit, 0, SUITS.size() - 1)]
	var fabric: Color = era[1]
	if _tex != null:
		# the art has empty margins left and right, so draw only the middle half
		var tw: float = float(_tex.get_width())
		var th: float = float(_tex.get_height())
		draw_texture_rect_region(_tex, Rect2(0.0, 0.0, h * 0.5, h), Rect2(tw * 0.25, 0.0, tw * 0.5, th), fabric)
		_details(str(era[2]))
	else:
		draw_circle(Vector2(h * 0.25, h * 0.2), h * 0.17, Color(0.1, 0.07, 0.16))
		draw_rect(Rect2(h * 0.08, h * 0.35, h * 0.34, h * 0.45), fabric)
		draw_rect(Rect2(h * 0.1, h * 0.8, h * 0.12, h * 0.2), fabric.darkened(0.3))
		draw_rect(Rect2(h * 0.28, h * 0.8, h * 0.12, h * 0.2), fabric.darkened(0.3))
	# the patch sits on the chest, like a real mission patch
	_draw_patch(_t(150, 108) if _tex != null else Vector2(h * 0.32, h * 0.45), maxf(3.0, h * 0.06))
	if _cheer_t >= 0.0:
		_draw_thumb()
	draw_set_transform(Vector2.ZERO)


## The details that make each suit recognisable.
func _details(kind: String) -> void:
	var red: Color = Color(0.82, 0.16, 0.18)
	var blue: Color = Color(0.16, 0.30, 0.66)
	var orange: Color = Color(0.96, 0.52, 0.16)
	match kind:
		"mercury":
			# silver suit: bright seams down the front and the legs
			_box(126, 84, 129, 160, Color(1, 1, 1, 0.7))
			_box(108, 170, 110, 205, Color(1, 1, 1, 0.5))
			_box(144, 170, 146, 205, Color(1, 1, 1, 0.5))
		"vostok":
			# orange coverall, white helmet with red letters on the brow
			_box(104, 10, 156, 20, Color(0.97, 0.97, 0.97))
			_box(114, 12, 146, 18, red)
		"apollo":
			# white suit, red commander stripes on the arms and legs, blue chest patch
			_box(78, 112, 92, 118, red)
			_box(162, 112, 176, 118, red)
			_box(98, 182, 124, 188, red)
			_box(132, 182, 158, 188, red)
			_box(136, 92, 152, 106, blue)
		"sokol":
			# white with blue cuffs, a blue zip line and blue boots
			_box(76, 134, 94, 142, blue)
			_box(160, 134, 178, 142, blue)
			_box(110, 84, 113, 158, blue)
			_box(92, 222, 162, 240, Color(blue, 0.85))
		"aces":
			# orange launch and entry suit, white shoulder patches, black boots
			_box(84, 88, 98, 100, Color(0.97, 0.97, 0.97))
			_box(156, 88, 170, 100, Color(0.97, 0.97, 0.97))
			_box(92, 222, 162, 242, Color(0.08, 0.08, 0.10))
		"emu":
			# white spacewalk suit, red stripes round the legs
			_box(98, 176, 124, 181, red)
			_box(132, 176, 158, 181, red)
			_box(98, 194, 124, 199, red)
			_box(132, 194, 158, 199, red)
		"feitian":
			# white with a red band across the chest and blue gloves
			_box(84, 102, 170, 110, red)
			_box(74, 140, 94, 152, blue)
			_box(160, 140, 180, 152, blue)
		"axemu":
			# dark suit with orange and blue trim
			_box(84, 98, 170, 102, orange)
			_box(98, 184, 124, 188, Color(0.30, 0.62, 0.92))
			_box(132, 184, 158, 188, Color(0.30, 0.62, 0.92))
			_box(92, 222, 162, 240, Color(0.15, 0.15, 0.17))


## A round patch with the chosen emblem and the player's initial.
func _draw_patch(centre: Vector2, radius: float) -> void:
	var entry: Array = PATCHES[clampi(_patch, 0, PATCHES.size() - 1)]
	var bg: Color = entry[1]
	draw_circle(centre, radius + maxf(1.0, radius * 0.12), Color(0.02, 0.05, 0.12))
	draw_circle(centre, radius, bg)
	draw_emblem(self, str(entry[2]), centre, radius * 0.8, Color(1, 1, 1, 0.92), bg)
	if _initial != "" and _height >= 200.0:
		var font: Font = ThemeDB.fallback_font
		var font_size: int = maxi(8, int(_height * 0.07))
		var text_size: Vector2 = font.get_string_size(_initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(font, _t(128, 250) + Vector2(-text_size.x * 0.5, 0.0), _initial, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1, 1, 1, 0.9))


## A raised arm with the thumb up, from the right shoulder, waving a little.
func _draw_thumb() -> void:
	var era: Array = SUITS[clampi(_suit, 0, SUITS.size() - 1)]
	var sleeve: Color = Color(era[1]).lerp(Color(0.93, 0.94, 0.96), 0.25)
	var edge: Color = Color(0.30, 0.32, 0.38)
	var wave: float = sin(_cheer_t * 7.0) * 0.18
	var shoulder: Vector2 = _t(168, 96)
	var arm_len: float = _height * 0.26
	var hand: Vector2 = shoulder + Vector2(0, -arm_len).rotated(0.45 + wave)
	var thick: float = _height * 0.075
	draw_line(shoulder, hand, edge, thick + 2.0)
	draw_line(shoulder, hand, sleeve, thick)
	draw_circle(shoulder, thick * 0.5, sleeve)
	# the glove: a fist with the thumb pointing up
	var fist: float = thick * 0.75
	draw_circle(hand, fist + 1.0, edge)
	draw_circle(hand, fist, Color(0.92, 0.92, 0.94))
	var thumb: Rect2 = Rect2(hand + Vector2(-fist * 0.28, -fist * 1.9), Vector2(fist * 0.56, fist * 1.2))
	draw_rect(thumb.grow(1.0), edge)
	draw_rect(thumb, Color(0.92, 0.92, 0.94))
