# PauseMenu.gd
extends CanvasLayer

@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var notes_btn:  Button = $Panel/VBoxContainer/NotesBtn2
@onready var quit_btn:   Button = $Panel/VBoxContainer/QuitBtn
@onready var panel:      PanelContainer = $Panel

@export var notes_panel: NodePath = ""
var _notes_ref: Control = null

# Remove @export var notes_panel and _notes_ref
# Instead get it from village scene via group

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(func(): _toggle())
	notes_btn.pressed.connect(func():
		_toggle()
		# Find NotesPanel via group
		var np = get_tree().get_first_node_in_group("notes_panel")
		if np: np.open()
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

	for btn in [resume_btn, notes_btn]:
		_style_btn(btn, Color("fdf6e3"), Color("4a7c59"))
	_style_btn(quit_btn, Color("fdf6e3"), Color("4a7c59"))

func _style_btn(btn: Button, text_col: Color, hover_text_col: Color) -> void:
	var normal = preload("res://assets/ui/button_normal.tres")
	var hover = preload("res://assets/ui/button_hover.tres")
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", hover_text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_font_size_override("font_size", 12)
	btn.custom_minimum_size = Vector2(180, 0)
