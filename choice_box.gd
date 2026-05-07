# ChoiceBox.gd — renders dialogue choices
extends PanelContainer

@onready var choice_list: VBoxContainer = $ChoiceList

func _ready() -> void:
	DialogueUI.register_choice_box(self)
	visible = false

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
	var normal = make_panel_style(false)
	var hover = make_panel_style(true)
	var pressed = normal.duplicate()

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color("2c1810"))
	btn.add_theme_color_override("font_color_hover", Color("fdf6e3"))
	btn.add_theme_font_size_override("font_size", 10)
	btn.custom_minimum_size = Vector2(200, 0)

func make_panel_style(is_hover:bool) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	if is_hover: style.texture = preload("res://assets/ui/sv_48x18xhover.png")
	else: style.texture = preload("res://assets/ui/sv_48x18.png")
	style.texture_margin_left   = 10
	style.texture_margin_right  = 2
	style.texture_margin_top    = 2
	style.texture_margin_bottom = 2
	return style
