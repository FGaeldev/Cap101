# ChoiceBox.gd — renders dialogue choices
extends PanelContainer

## Minimum height (px) of one choice button; buttons grow past this to fill.
const MIN_CHOICE_HEIGHT: float = 24.0

@onready var choice_list: VBoxContainer = $ChoiceList
func _ready() -> void:
	$".".add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# Claim all free vertical space in TextColumn (DialogueRoot.tscn sets 0/shrink
	# on this instance; _ready runs after, so this wins) and split it evenly.
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 3)
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
		# Fill the row; wrap long labels instead of widening the box.
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, MIN_CHOICE_HEIGHT)
		_style_choice_btn(btn)
		btn.pressed.connect(func():
			hide_choices()
			component.choose(c)
		)
		choice_list.add_child(btn)

	visible = true

func hide_choices() -> void:
	visible = false

func _style_choice_btn(btn: Button) -> void:
	UIThemeApplier.apply_button_theme(btn, "secondary")
	btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
