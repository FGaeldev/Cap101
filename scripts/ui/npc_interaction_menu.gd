# npc_interaction_menu.gd
## Lightweight NPC action menu. Story/cutscene routing stays in the NPC script.
extends PanelContainer

signal choice_selected(choice: String)

const DISABLED_TALK_NOTE := "disabled as reworking idle_pool system (10/19/2026)"

var _title_label: Label


func _ready() -> void:
	# Keep menu centered and usable across Android viewport sizes.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -160.0
	offset_right = 160.0
	offset_top = -140.0
	offset_bottom = 140.0
	custom_minimum_size = Vector2(320.0, 280.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	layout.add_child(_title_label)

	var talk_button := Button.new()
	talk_button.text = "Talk"
	talk_button.disabled = true
	talk_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(talk_button, "secondary")
	layout.add_child(talk_button)

	var disabled_note := Label.new()
	disabled_note.text = DISABLED_TALK_NOTE
	disabled_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	disabled_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disabled_note.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	disabled_note.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	layout.add_child(disabled_note)

	var review_button := Button.new()
	review_button.text = "Review"
	review_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(review_button, "primary")
	review_button.pressed.connect(func() -> void:
		choice_selected.emit("review")
	)
	layout.add_child(review_button)

	var goodbye_button := Button.new()
	goodbye_button.text = "Goodbye"
	goodbye_button.custom_minimum_size.y = 36.0
	UIThemeApplier.apply_button_theme(goodbye_button, "secondary")
	goodbye_button.pressed.connect(func() -> void:
		choice_selected.emit("goodbye")
	)
	layout.add_child(goodbye_button)

	visible = false


## Opens menu for an NPC; called only after NPC cutscene routing is checked.
func open(npc_display_name: String) -> void:
	_title_label.text = npc_display_name if not npc_display_name.is_empty() else "NPC"
	visible = true


func close() -> void:
	visible = false
