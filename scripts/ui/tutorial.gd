extends Control
## A short first-visit tip box. Call  Tutorial.maybe_show(self, "workshop")  at the
## end of a screen's _ready(). It shows once per screen, then remembers (GameState).
## While it is open GameState.tutorial_open is true, so game clocks can wait.

const UI = preload("res://scripts/ui/ui.gd")
const Data = preload("res://scripts/core/data.gd")
const Self = preload("res://scripts/ui/tutorial.gd")
const PATH: String = "res://data/tutorial.json"

var _screen_id: String = ""
var _title: String = ""
var _steps: Array = []
var _index: int = 0
var _step_label: Label = null
var _body: VBoxContainer = null
var _next: Button = null


## Shows the tips for screen_id on host, unless they were already seen.
static func maybe_show(host: Control, screen_id: String) -> void:
	if bool(GameState.tutorial_seen.get(screen_id, false)):
		return
	var cfg: Dictionary = Data.load_dict(PATH)
	var screens: Dictionary = cfg.get("screens", {})
	if not screens.has(screen_id):
		return
	var entry: Dictionary = screens[screen_id]
	var steps: Array = entry.get("steps", [])
	if steps.is_empty():
		return
	var overlay: Control = Self.new()
	overlay.call("setup", screen_id, str(entry.get("title", "")), steps)
	host.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(screen_id: String, title: String, steps: Array) -> void:
	_screen_id = screen_id
	_title = title
	_steps = steps


## Fills {placeholders} from the level data so the tips never show stale numbers.
static func fill(text: String) -> String:
	var level: Dictionary = GameState.level
	var limits: Dictionary = level.get("limits", {})
	var ops: Dictionary = level.get("ops", {})
	var stars: Dictionary = level.get("stars", {})
	var out: String = text
	out = out.replace("{goal}", str(level.get("goal_text", "")))
	out = out.replace("{mass_kg}", "%.1f" % float(limits.get("mass_kg", 0.0)))
	out = out.replace("{budget}", UI.money(float(limits.get("budget_k", 0.0))))
	out = out.replace("{deadline}", str(int(float(limits.get("deadline_day", 0.0)))))
	out = out.replace("{weeks}", str(int(float(ops.get("weeks", 0.0)))))
	out = out.replace("{goal_mb}", str(int(float(ops.get("goal_mb", 0.0)))))
	out = out.replace("{reserve_pct}", str(int(float(stars.get("reserve_pct", 0.0)))))
	return out


func _ready() -> void:
	GameState.tutorial_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre: CenterContainer = CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UI.panel(UI.C_CYAN, 22.0)
	panel.custom_minimum_size = Vector2(600.0, 0.0)
	centre.add_child(panel)
	var col: VBoxContainer = UI.vbox(12)
	panel.add_child(col)
	col.add_child(UI.label("How to play: " + _title, 24, UI.C_CYAN))
	_step_label = UI.label("", 13, UI.C_MUTED)
	col.add_child(_step_label)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(556.0, 110.0)
	col.add_child(_body)
	var row: HBoxContainer = UI.hbox(12)
	col.add_child(row)
	row.add_child(UI.button("Skip tips", _finish, 160.0, false))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next = UI.button("Next", _on_next, 160.0, true)
	row.add_child(_next)
	_show_step()


func _exit_tree() -> void:
	GameState.tutorial_open = false


func _show_step() -> void:
	_step_label.text = "Tip %d of %d" % [_index + 1, _steps.size()]
	UI.clear(_body)
	var step: Variant = _steps[_index]
	var lines: Array = []
	if typeof(step) == TYPE_ARRAY:
		for item in step:
			lines.append(fill(str(item)))
	else:
		lines.append(fill(str(step)))
	_body.add_child(UI.bullets(lines, 17, UI.C_TEXT, 556.0))
	_next.text = "Got it" if _index == _steps.size() - 1 else "Next"


func _on_next() -> void:
	if _index >= _steps.size() - 1:
		_finish()
		return
	_index += 1
	_show_step()


func _finish() -> void:
	GameState.mark_tutorial_seen(_screen_id)
	GameState.tutorial_open = false
	queue_free()
