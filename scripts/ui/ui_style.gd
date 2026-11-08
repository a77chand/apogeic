## Shared look for popups. Godot's default panel is see-through, which makes text
## hard to read over the base, so popups use this solid one instead.
extends RefCounted


## A solid rounded panel with a thin border.
static func solid_panel(border: Color = Color(0.4, 0.45, 0.55)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.13, 0.17)
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	return box
