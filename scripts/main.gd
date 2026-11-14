extends Control
## The only scene that is ever loaded. It swaps one screen in and out.
## A screen is a script that extends Control and builds its own nodes in _ready().
## To add a screen: write the script, then add one line to SCREENS.

const UI = preload("res://scripts/ui/ui.gd")
const Stub = preload("res://scripts/screens/stub.gd")
const Sfx = preload("res://scripts/ui/sfx.gd")

## screen id -> script path. A missing script shows the stub screen instead of crashing.
const SCREENS: Dictionary = {
	"title": "res://scripts/screens/title.gd",
	"ladder": "res://scripts/screens/ladder.gd",
	"puzzle_mass": "res://scripts/screens/puzzle_mass.gd",
	"puzzle_power": "res://scripts/screens/puzzle_power.gd",
	"puzzle_link": "res://scripts/screens/puzzle_link.gd",
	"puzzle_time": "res://scripts/screens/puzzle_time.gd",
	"briefing": "res://scripts/screens/briefing.gd",
	"workshop": "res://scripts/screens/workshop.gd",
	"test_lab": "res://scripts/screens/test_lab.gd",
	"launch": "res://scripts/screens/launch.gd",
	"ops": "res://scripts/screens/ops.gd",
	"report": "res://scripts/screens/report.gd",
	"truck": "res://scripts/screens/truck.gd",
}

## The order the stub screens walk through, so the whole game is clickable from day one.
const FLOW: Array = ["title", "ladder", "puzzle_mass", "puzzle_power", "puzzle_link", "puzzle_time",
		"briefing", "workshop", "test_lab", "launch", "ops", "report"]

var _current: Control = null
var _holder: Control = null
var _current_id: String = ""


## F11 or Alt+Enter toggles fullscreen. The game scales to fit any window size.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: InputEventKey = event
		if key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed):
			var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			if full:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()


func _ready() -> void:
	GameState.router = self
	var sfx: Node = Sfx.new()
	add_child(sfx)
	GameState.sfx = sfx
	add_child(UI.background())
	add_child(UI.vignette())
	# Screens are laid out for 1280 x 720. They sit centred in this holder, and the
	# space background behind it fills any extra window area.
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_holder.set_anchors_preset(Control.PRESET_CENTER)
	_holder.offset_left = -640.0
	_holder.offset_right = 640.0
	_holder.offset_top = -360.0
	_holder.offset_bottom = 360.0
	go("title")


func go(screen_id: String) -> void:
	call_deferred("_swap", screen_id)


func current_id() -> String:
	return _current_id


func next_in_flow(screen_id: String) -> String:
	var index: int = FLOW.find(screen_id)
	if index < 0 or index + 1 >= FLOW.size():
		return "title"
	return str(FLOW[index + 1])


func _swap(screen_id: String) -> void:
	if _current != null:
		_holder.remove_child(_current)
		_current.queue_free()
		_current = null
	var path: String = str(SCREENS.get(screen_id, ""))
	var screen: Control = null
	if path != "" and ResourceLoader.exists(path):
		var script: GDScript = load(path)
		if script != null:
			var made: Variant = script.new()
			if made is Control:
				screen = made
	if screen == null:
		var stub: Control = Stub.new()
		stub.set("screen_id", screen_id)
		screen = stub
	_current = screen
	_current_id = screen_id
	_holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.modulate = Color(1, 1, 1, 0)   # fade in, so changing screen is not a hard cut
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.2)
