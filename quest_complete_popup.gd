# QuestCompletePopup.gd
extends CanvasLayer

@onready var title_label:     Label  = $Panel/VBoxContainer/TitleLabel
@onready var quest_name_label: Label = $Panel/VBoxContainer/QuestNameLabel
@onready var ok_btn:          Button = $Panel/VBoxContainer/OkBtn
@onready var panel:           PanelContainer = $Panel

func _ready() -> void:
	visible = false
	ok_btn.pressed.connect(func(): visible = false)
	QuestManager.quest_completed.connect(_on_quest_completed)
	_apply_style()

func _on_quest_completed(quest_id: String) -> void:
	var q = QuestManager.quests.get(quest_id, {})
	quest_name_label.text = q.get("title", quest_id)
	visible = true

func _apply_style() -> void:
	# Center panel on screen
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(220, 0)

	title_label.add_theme_color_override("font_color", Color("4a7c59"))
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "Hatuman ro Sugo!"

	quest_name_label.add_theme_color_override("font_color", Color("2c1810"))
	quest_name_label.add_theme_font_size_override("font_size", 11)
	quest_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var btn_normal = preload("res://assets/ui/button_normal.tres")
	var btn_hover = preload("res://assets/ui/button_hover.tres")
	var btn_pressed = preload("res://assets/ui/button_normal.tres")
	ok_btn.add_theme_color_override("font_color",          Color("f0faf0"))
	ok_btn.add_theme_color_override("font_hover_color",    Color("1a2e0a"))
	ok_btn.add_theme_color_override("font_color_pressed",  Color("f0faf0"))
	ok_btn.add_theme_stylebox_override("normal", btn_normal)
	ok_btn.add_theme_stylebox_override("hover", btn_hover)
	ok_btn.add_theme_stylebox_override("pressed", btn_pressed)
	ok_btn.add_theme_font_size_override("font_size", 12)
