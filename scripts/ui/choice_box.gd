# ChoiceBox.gd — renders dialogue choices
extends PanelContainer

@onready var choice_list: VBoxContainer = $ChoiceList
func _ready() -> void:
	$".".add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	UIThemeApplier.apply_button_theme(btn, "secondary")
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
