## One square in the base view: a single module and what it's doing.
## Shows art/modules/<id>.png if it exists, otherwise a colored grey-box square.
extends PanelContainer

const Art = preload("res://scripts/ui/art.gd")

const STATUS_TEXT := {
	"working": "",
	"off": "OFF",
	"broken": "BROKEN",
	"building": "BUILDING",
	"planned": "PLANNED",
}
const STATUS_COLOR := {
	"off": Color(1, 0.75, 0.3),
	"broken": Color(1, 0.4, 0.35),
	"building": Color(0.7, 0.8, 1),
	"planned": Color(0.8, 0.8, 0.8),
}

@onready var box: ColorRect = $VBox/Picture/Box
@onready var picture: TextureRect = $VBox/Picture/Art
@onready var name_label: Label = $VBox/Name
@onready var status_label: Label = $VBox/Status


## `status` is one of the keys of STATUS_TEXT. `note` adds detail, like "2 sols".
func setup(module_id: String, module_name: String, color: Color, status: String, note: String = "") -> void:
	name_label.text = module_name
	box.color = color
	var tex := Art.module_texture(module_id)
	picture.texture = tex
	box.visible = tex == null
	var text: String = STATUS_TEXT[status]
	if note != "":
		text += " " + note
	status_label.text = text
	if STATUS_COLOR.has(status):
		status_label.add_theme_color_override("font_color", STATUS_COLOR[status])
	# Fade modules that aren't doing anything yet, darken ones that are off or broken.
	match status:
		"planned":
			$VBox/Picture.modulate = Color(1, 1, 1, 0.3)
		"building":
			$VBox/Picture.modulate = Color(1, 1, 1, 0.55)
		"off", "broken":
			$VBox/Picture.modulate = Color(0.45, 0.45, 0.45)
