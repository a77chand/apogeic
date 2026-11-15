extends Control
## A drawing of a real rocket, made from its real shape: how tall and thin it is, its main
## colours, how many strap-on boosters it has and how long they are, fins, and the shape
## of the nose. It is a simple side view, not a scale model, but each rocket keeps the
## features people recognise it by (the R-7's four tapering boosters, Delta II's nine
## solid motors, PSLV's six strap-ons, Falcon 9's black interstage and landing legs...).
##   var art: Control = RocketArt.new()
##   art.rocket = "Falcon 9"

const UI = preload("res://scripts/ui/ui.gd")

const WHITE: Color = Color(0.93, 0.94, 0.96)
const GREY: Color = Color(0.62, 0.65, 0.70)
const DARK: Color = Color(0.16, 0.17, 0.20)
const GREEN: Color = Color(0.42, 0.50, 0.40)
const TEAL: Color = Color(0.40, 0.62, 0.76)
const RUST: Color = Color(0.70, 0.46, 0.30)

## w = width of the core (share of the height), boosters = how many show from the side,
## blen = booster length (share of the core), bcol = booster colour, nose = "cone",
## "ogive" or "bulb" (a wide payload fairing), fins = small fins at the base, bands =
## [from, to, colour] stripes as shares of the height from the bottom, legs = landing legs.
const SPECS: Dictionary = {
	"R-7 Sputnik": {"w": 0.075, "body": GREY, "boosters": 2, "blen": 0.55, "bcol": GREY, "taper": true, "nose": "cone", "bands": [[0.62, 0.66, DARK]]},
	"Juno I": {"w": 0.055, "body": WHITE, "nose": "ogive", "fins": true, "bands": [[0.1, 0.2, DARK], [0.3, 0.4, DARK], [0.5, 0.6, DARK], [0.78, 0.9, GREY]]},
	"Vanguard": {"w": 0.06, "body": WHITE, "nose": "cone", "fins": true, "bands": [[0.55, 0.6, DARK], [0.75, 0.78, DARK]]},
	"Long March 1": {"w": 0.075, "body": WHITE, "nose": "ogive", "fins": true, "bands": [[0.45, 0.48, Color(0.75, 0.15, 0.15)]]},
	"Kosmos-3M": {"w": 0.06, "body": GREEN, "nose": "cone", "bands": [[0.62, 0.66, DARK]]},
	"Delta 900": {"w": 0.07, "body": WHITE, "boosters": 3, "blen": 0.28, "bcol": WHITE, "nose": "bulb", "bands": [[0.0, 0.62, Color(0.80, 0.82, 0.86)]]},
	"Delta 2310": {"w": 0.07, "body": WHITE, "boosters": 2, "blen": 0.28, "bcol": WHITE, "nose": "bulb", "bands": [[0.0, 0.62, Color(0.80, 0.82, 0.86)]]},
	"Delta II": {"w": 0.075, "body": TEAL, "boosters": 3, "blen": 0.30, "bcol": WHITE, "nose": "bulb", "bands": [[0.62, 1.0, WHITE]]},
	"Rokot": {"w": 0.065, "body": WHITE, "nose": "ogive", "bands": [[0.72, 0.75, DARK]]},
	"PSLV": {"w": 0.075, "body": RUST, "boosters": 3, "blen": 0.22, "bcol": Color(0.78, 0.56, 0.42), "nose": "bulb", "bands": [[0.42, 0.75, WHITE]]},
	"PSLV-XL": {"w": 0.075, "body": RUST, "boosters": 3, "blen": 0.32, "bcol": Color(0.78, 0.56, 0.42), "nose": "bulb", "bands": [[0.42, 0.75, WHITE]]},
	"Dnepr": {"w": 0.12, "body": Color(0.36, 0.43, 0.34), "nose": "bulb", "short": 0.7, "bands": [[0.8, 0.83, DARK]]},
	"Antares": {"w": 0.09, "body": WHITE, "nose": "bulb", "bands": [[0.55, 0.68, DARK]]},
	"Proton-K": {"w": 0.09, "body": WHITE, "boosters": 2, "blen": 0.40, "bcol": WHITE, "nose": "bulb", "bands": [[0.40, 0.43, GREY], [0.62, 0.65, GREY]]},
	"Zenit-2SB": {"w": 0.085, "body": WHITE, "nose": "bulb", "bands": [[0.58, 0.61, DARK]]},
	"H-IIA": {"w": 0.08, "body": WHITE, "boosters": 2, "blen": 0.32, "bcol": WHITE, "nose": "bulb", "bands": [[0.0, 0.58, Color(0.95, 0.62, 0.30)]]},
	"Vostok-K": {"w": 0.07, "body": GREY, "boosters": 2, "blen": 0.52, "bcol": GREY, "taper": true, "nose": "bulb", "bands": [[0.66, 0.70, DARK], [0.78, 0.92, Color(0.85, 0.86, 0.88)]]},
	"Ariane 5": {"w": 0.085, "body": WHITE, "boosters": 2, "blen": 0.62, "bcol": WHITE, "nose": "bulb", "bands": [[0.02, 0.06, DARK]]},
	"Falcon 9": {"w": 0.06, "body": WHITE, "nose": "bulb", "legs": true, "bands": [[0.66, 0.71, DARK], [0.02, 0.06, DARK]]},
	"Astra Rocket 3.3": {"w": 0.07, "body": Color(0.29, 0.30, 0.33), "nose": "ogive", "short": 0.55, "bands": [[0.6, 1.0, WHITE]]},
}

var rocket: String = ""
var show_name: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var spec: Dictionary = SPECS.get(rocket, {"w": 0.07, "body": WHITE, "nose": "cone"})
	var name_h: float = 34.0 if show_name else 0.0
	var full: float = size.y - name_h - 6.0
	var h: float = full * float(spec.get("short", 1.0))
	var w: float = full * float(spec.get("w", 0.07))
	var cx: float = size.x * 0.5
	var base: float = full
	var top: float = base - h
	var body: Color = spec.get("body", WHITE)
	var nose_h: float = h * 0.12
	var core: Rect2 = Rect2(cx - w * 0.5, top + nose_h, w, h - nose_h)
	# a faint glow behind it
	draw_circle(Vector2(cx, base - h * 0.5), h * 0.35, Color(UI.C_ACCENT, 0.05))
	# boosters behind the core
	var n: int = int(spec.get("boosters", 0))
	if n > 0:
		var bl: float = h * float(spec.get("blen", 0.3))
		var bw: float = w * 0.55
		var bcol: Color = spec.get("bcol", WHITE)
		var sides: Array = [-1.0, 1.0] if n >= 2 else [-1.0]
		if n >= 3:
			sides.append(0.0)
		for sx in sides:
			var x: float = cx + float(sx) * (w * 0.5 + bw * 0.42) - bw * 0.5
			var col: Color = bcol.darkened(0.12) if float(sx) == 0.0 else bcol
			if bool(spec.get("taper", false)):
				# the R-7's boosters: cones that widen towards the bottom
				var t0: Vector2 = Vector2(x + bw * 0.5, base - bl)
				draw_colored_polygon(PackedVector2Array([t0, Vector2(x + bw * 1.1, base), Vector2(x - bw * 0.1, base)]), col)
			else:
				draw_rect(Rect2(x, base - bl, bw, bl), col)
				draw_colored_polygon(PackedVector2Array([Vector2(x, base - bl), Vector2(x + bw * 0.5, base - bl - bw * 1.1), Vector2(x + bw, base - bl)]), col)
	# the core and its stripes
	draw_rect(core, body)
	for item in spec.get("bands", []):
		var band: Array = item
		var y0: float = base - h * float(band[1])
		var y1: float = base - h * float(band[0])
		var r: Rect2 = Rect2(core.position.x, maxf(y0, core.position.y), w, minf(y1, base) - maxf(y0, core.position.y))
		if r.size.y > 0.0:
			draw_rect(r, band[2])
	# shading down the right side, a highlight on the left
	draw_rect(Rect2(core.position.x + w * 0.68, core.position.y, w * 0.32, core.size.y), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(core.position.x + w * 0.12, core.position.y, w * 0.12, core.size.y), Color(1, 1, 1, 0.12))
	# the nose
	var nose: String = str(spec.get("nose", "cone"))
	var nt: float = core.position.y
	if nose == "bulb":
		var fw: float = w * 1.25
		draw_rect(Rect2(cx - fw * 0.5, nt - nose_h * 0.2, fw, nose_h * 0.7), WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - fw * 0.5, nt - nose_h * 0.2), Vector2(cx, top - nose_h * 0.1), Vector2(cx + fw * 0.5, nt - nose_h * 0.2)]), WHITE)
	elif nose == "ogive":
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(11):
			var t: float = float(i) / 10.0
			pts.append(Vector2(cx - w * 0.5 * cos(t * PI * 0.5), nt - nose_h * sin(t * PI * 0.5)))
		for i in range(10, -1, -1):
			var t: float = float(i) / 10.0
			pts.append(Vector2(cx + w * 0.5 * cos(t * PI * 0.5), nt - nose_h * sin(t * PI * 0.5)))
		draw_colored_polygon(pts, body if body != Color(0.29, 0.30, 0.33) else WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5, nt), Vector2(cx, top), Vector2(cx + w * 0.5, nt)]), body)
	# fins and legs
	if bool(spec.get("fins", false)):
		draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.5, base - h * 0.12), Vector2(cx - w * 1.1, base), Vector2(cx - w * 0.5, base)]), GREY)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + w * 0.5, base - h * 0.12), Vector2(cx + w * 1.1, base), Vector2(cx + w * 0.5, base)]), GREY)
	if bool(spec.get("legs", false)):
		draw_line(Vector2(cx - w * 0.45, base - h * 0.08), Vector2(cx - w * 1.2, base), DARK, 2.0)
		draw_line(Vector2(cx + w * 0.45, base - h * 0.08), Vector2(cx + w * 1.2, base), DARK, 2.0)
	# the engine bell
	draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.25, base), Vector2(cx + w * 0.25, base), Vector2(cx + w * 0.35, base + 6.0), Vector2(cx - w * 0.35, base + 6.0)]), DARK)
	if show_name and rocket != "":
		var font: Font = UI.pixel_font(false)
		var lines: PackedStringArray = rocket.to_upper().split(" ")
		var y: float = size.y - name_h + 8.0
		var line: String = ""
		var rows: Array = []
		for word in lines:
			var test: String = (line + " " + word).strip_edges()
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > size.x - 4.0 and line != "":
				rows.append(line)
				line = word
			else:
				line = test
		rows.append(line)
		for row in rows:
			var tw: float = font.get_string_size(str(row), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, Vector2(cx - tw * 0.5, y), str(row), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(UI.C_ACCENT, 0.9))
			y += 12.0
