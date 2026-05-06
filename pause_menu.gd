# PauseMenu.gd
extends CanvasLayer

@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var notes_btn:  Button = $Panel/VBoxContainer/NotesBtn2
@onready var quit_btn:   Button = $Panel/VBoxContainer/QuitBtn
@onready var panel:      PanelContainer = $Panel

@export var notes_panel: NodePath = ""
var _notes_ref: Control = null

func _ready() -> void:
	visible = false
	if notes_panel:
		_notes_ref = get_node(notes_panel)
	resume_btn.pressed.connect(func(): _toggle())
	notes_btn.pressed.connect(func():
		_toggle()
		if _notes_ref: _notes_ref.open()
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
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color     = Color("fdf6e3")
	panel_style.border_color = Color("5c3a1e")
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(200, 0)

	var paused_label: Label = $Panel/VBoxContainer/PausedLabel
	paused_label.add_theme_color_override("font_color", Color("5c3a1e"))
	paused_label.add_theme_font_size_override("font_size", 16)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for btn in [resume_btn, notes_btn]:
		_style_btn(btn, Color("4a7c59"), Color("fdf6e3"))
	_style_btn(quit_btn, Color("5c3a1e"), Color("fdf6e3"))

func _style_btn(btn: Button, bg: Color, text_col: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color     = bg
	normal.border_color = bg.darkened(0.3)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	normal.set_content_margin(SIDE_LEFT, 20)
	normal.set_content_margin(SIDE_RIGHT, 20)
	normal.set_content_margin(SIDE_TOP, 7)
	normal.set_content_margin(SIDE_BOTTOM, 7)
	var hover = normal.duplicate()
	hover.bg_color = bg.lightened(0.15)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(180, 0)
