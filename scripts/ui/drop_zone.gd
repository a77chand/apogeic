extends PanelContainer
## A target that accepts a dragged part card. accept_category "" means any category.
## Children of a drop zone should use MOUSE_FILTER_IGNORE so they do not block the drop.

signal part_dropped(part_id: String)

var accept_category: String = ""


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if str(d.get("type", "")) != "part":
		return false
	if accept_category == "":
		return true
	var parts: Dictionary = GameState.parts
	var part_id: String = str(d.get("id", ""))
	if not parts.has(part_id):
		return false
	var part: Dictionary = parts[part_id]
	return str(part.get("category", "")) == accept_category


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var d: Dictionary = data
	part_dropped.emit(str(d.get("id", "")))
