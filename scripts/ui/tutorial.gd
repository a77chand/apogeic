extends Control
## A short first-visit tip box. Call  Tutorial.maybe_show(self, "workshop")  at the
## end of a screen's _ready(). It shows once per screen, then remembers (GameState).
## While it is open GameState.tutorial_open is true, so game clocks can wait.
## Each tip types itself out, line by line (about five seconds for a whole intro);
## pressing Next while it types shows the rest at once.

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
var _typing: Tween = null
var _typed: Array = []


## Shows the tips for screen_id on host, unless they were already seen.
static func maybe_show(host: Control, screen_id: String) -> void:
	if not GameState.tips_on or bool(GameState.tutorial_seen.get(screen_id, false)):
		return
	var cfg: Dictionary = Data.load_dict(PATH)
	var screens: Dictionary = cfg.get("screens", {})
	if not screens.has(screen_id):
		return
	var entry: Dictionary = screens[screen_id]
	var steps: Array = _only_if_needed(entry.get("steps", []))
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
	z_index = 100   # always above the screen, including raised cards
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
	_type_out()


## Types every line of the current tip, one after another.
func _type_out() -> void:
	_typed = []
	for node in _body.find_children("*", "Label", true, false):
		var l: Label = node
		if l.text.length() > 2:
			l.visible_ratio = 0.0
			_typed.append(l)
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	for item in _typed:
		var l: Label = item
		_typing.tween_property(l, "visible_ratio", 1.0, clampf(float(l.text.length()) / 40.0, 0.3, 2.0))
		_typing.tween_callback(GameState.play_sound.bind("select"))


func _skip_typing() -> bool:
	if _typing != null and _typing.is_running():
		_typing.kill()
		for item in _typed:
			(item as Label).visible_ratio = 1.0
		return true
	return false


func _on_next() -> void:
	if _skip_typing():
		return
	if _index >= _steps.size() - 1:
		_finish()
		return
	_index += 1
	_show_step()


func _finish() -> void:
	GameState.mark_tutorial_seen(_screen_id)
	GameState.tutorial_open = false
	queue_free()


## Lines marked "[locked]" only apply when this mission has a locked choice (most missions
## have none). Drops those lines when there is none, and any step left empty.
static func _only_if_needed(steps: Array) -> Array:
	var has_locked: bool = false
	for item in GameState.level.get("concept_chips", []):
		if str((item as Dictionary).get("state", "")) == "locked":
			has_locked = true
	var out: Array = []
	for step in steps:
		var lines: Array = step if typeof(step) == TYPE_ARRAY else [step]
		var kept: Array = []
		for line in lines:
			var t: String = str(line)
			if t.begins_with("[locked] "):
				if not has_locked:
					continue
				t = t.substr(9)
			kept.append(t)
		if not kept.is_empty():
			out.append(kept)
	return out
