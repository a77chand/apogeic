extends Control
## Placeholder for a screen that is not written yet. It shows the screen id and a
## Next button that follows the flow, so the game is always clickable end to end.

const UI = preload("res://scripts/ui/ui.gd")

var screen_id: String = ""


func _ready() -> void:
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p: PanelContainer = UI.panel()
	center.add_child(p)
	var v: VBoxContainer = UI.vbox(14)
	p.add_child(v)
	v.add_child(UI.label("Screen not built yet", 14, UI.C_MUTED))
	v.add_child(UI.label(screen_id, 34))
	v.add_child(UI.button("Next screen", _on_next, 240.0, true))
	v.add_child(UI.button("Back to title", _on_title))


func _on_next() -> void:
	var next_id: String = "title"
	if GameState.router != null:
		next_id = str(GameState.router.call("next_in_flow", screen_id))
	GameState.go(next_id)


func _on_title() -> void:
	GameState.go("title")
