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
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color     = Color("fdf6e3")
	panel_style.border_color = Color("e8b84b")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Center panel on screen
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(220, 0)

	title_label.add_theme_color_override("font_color", Color("4a7c59"))
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "Quest Complete!"

	quest_name_label.add_theme_color_override("font_color", Color("2c1810"))
	quest_name_label.add_theme_font_size_override("font_size", 11)
	quest_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color     = Color("4a7c59")
	btn_normal.border_color = Color("2d5e3a")
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(3)
	btn_normal.set_content_margin(SIDE_LEFT, 30)
	btn_normal.set_content_margin(SIDE_RIGHT, 30)
	btn_normal.set_content_margin(SIDE_TOP, 6)
	btn_normal.set_content_margin(SIDE_BOTTOM, 6)
	ok_btn.add_theme_stylebox_override("normal", btn_normal)
	ok_btn.add_theme_color_override("font_color", Color("fdf6e3"))
	ok_btn.add_theme_font_size_override("font_size", 12)
