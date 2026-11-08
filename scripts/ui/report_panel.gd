## The end-of-sol report that pops up after End sol. Important lines (problems,
## warnings, good news) come first; the made/used numbers go under "Details".
extends Control

signal closed

const UiStyle = preload("res://scripts/ui/ui_style.gd")

const KIND_COLOR := {
	"bad": Color(1, 0.45, 0.4),
	"warn": Color(1, 0.8, 0.35),
	"good": Color(0.45, 0.9, 0.5),
	"info": Color(0.75, 0.78, 0.85),
}

@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var main_list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/Lines/Main
@onready var details_title: Label = $Center/Panel/Margin/VBox/Scroll/Lines/DetailsTitle
@onready var details_list: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/Lines/Details
@onready var continue_button: Button = $Center/Panel/Margin/VBox/ContinueButton


func _ready() -> void:
	$Center/Panel.add_theme_stylebox_override("panel", UiStyle.solid_panel())
	continue_button.pressed.connect(_on_continue)
	hide()


## `sol` is the sol the report is about (the one that just ended).
func show_report(day_word: String, sol: int, report: Array) -> void:
	title.text = "%s %d report" % [day_word, sol]
	for list in [main_list, details_list]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	for line in report:
		var target := details_list if line.kind == "info" else main_list
		_add_line(target, line.text, KIND_COLOR.get(line.kind, Color.WHITE))
	if main_list.get_child_count() == 0:
		_add_line(main_list, "A quiet %s. Everything ran normally." % day_word.to_lower(), KIND_COLOR.good)
	details_title.visible = details_list.get_child_count() > 0
	show()
	continue_button.grab_focus()  # so Enter/Space closes the report


func _add_line(list: VBoxContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	if list == details_list:
		label.add_theme_font_size_override("font_size", 14)
	list.add_child(label)


func _on_continue() -> void:
	hide()
	closed.emit()
