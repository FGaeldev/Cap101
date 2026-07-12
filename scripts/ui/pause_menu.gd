# PauseMenu.gd
extends CanvasLayer

@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var dict_btn:   Button = $Panel/VBoxContainer/NotesBtn2
@onready var quit_btn:   Button = $Panel/VBoxContainer/QuitBtn
@onready var panel:      PanelContainer = $Panel

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(func(): _toggle())
	dict_btn.pressed.connect(func():
		_toggle()
		# Find DictionaryPanel via group
		var dp = get_tree().get_first_node_in_group("dictionary_panel")
		if dp: dp.open()
	)
	quit_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	)
	_apply_style()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()

func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible

func _apply_style() -> void:
	var panel_style = preload("res://assets/ui/panelStyle.tres")
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(200, 0)

	var paused_label: Label = $Panel/VBoxContainer/PausedLabel
	paused_label.add_theme_color_override("font_color", Color("5c3a1e"))
	paused_label.add_theme_font_size_override("font_size", 16)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for btn in [resume_btn, dict_btn]:
		_style_btn(btn,"primary")
	_style_btn(quit_btn,"danger")

func _style_btn(btn: Button, variant: String) -> void:
	UIThemeApplier.apply_button_theme(btn, variant)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(180, 0)
