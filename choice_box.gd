# ChoiceBox.gd — renders dialogue choices
extends PanelContainer

@onready var choice_list: VBoxContainer = $ChoiceList

func _ready() -> void:
	DialogueUI.register_choice_box(self)
	visible = false
	_apply_style()

func _apply_style() -> void:
	var panel = StyleBoxFlat.new()
	panel.bg_color     = Color("fdf6e3")
	panel.border_color = Color("5c3a1e")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel)

func show_choices(choices: Array, component: DialogueComponent) -> void:
	# Clear old buttons
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.free()

	for c in choices:
		var btn = Button.new()
		btn.text = c.get("label", "...")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_choice_btn(btn)
		var next = c.get("next", -1)
		btn.pressed.connect(func():
			hide_choices()
			component.choose(next)
		)
		choice_list.add_child(btn)

	visible = true

func hide_choices() -> void:
	visible = false

func _style_choice_btn(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color     = Color("fffdf5")
	normal.border_color = Color("c8a96e")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.set_content_margin(SIDE_LEFT, 10)
	normal.set_content_margin(SIDE_RIGHT, 10)
	normal.set_content_margin(SIDE_TOP, 6)
	normal.set_content_margin(SIDE_BOTTOM, 6)
	var hover = normal.duplicate()
	hover.bg_color     = Color("4a7c59")
	hover.border_color = Color("2d5e3a")
	var pressed = normal.duplicate()
	pressed.bg_color = Color("2d5e3a")

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("2c1810"))
	btn.add_theme_color_override("font_color_hover", Color("fdf6e3"))
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(200, 0)
