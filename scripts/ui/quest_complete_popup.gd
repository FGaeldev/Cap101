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
	# Utility/tutorial quests (e.g. movement tutorial, completion_trigger-based)
	# complete via QuestManager same as narrative quests, but shouldn't fire
	# this celebratory popup — mark them "show_popup": false in quest_data.json.
	if not q.get("show_popup", true):
		return
	quest_name_label.text = q.get("title", quest_id)
	visible = true

func _apply_style() -> void:
	# Center panel on screen
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(220, 0)
	# Was panelStyle.tres (sv_48.png, legacy Stardew-style texture, UI Style
	# Guide §7 — retire alongside dictionary_panel.gd). Now matches BookUI
	# chrome via UIThemeApplier, same generic popup style as puzzle_panel.
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style())

	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XXL)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "Hatuman ro Sugo!"

	quest_name_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	quest_name_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	quest_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	UIThemeApplier.apply_button_theme(ok_btn, "confirm")
	ok_btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
