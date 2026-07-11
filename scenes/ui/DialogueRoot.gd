# DialogueRoot.gd — outer shell for the dialogue UI.
# Owns: background panel (single draw, no double-panels from children),
# the 45%-of-screen-height cap, and the speaker portrait on the right.
# DialogueBox (text) + ChoiceBox (options) live inside as a plain text column.
extends PanelContainer

@onready var portrait: TextureRect = $Margin/Layout/Portrait

func _ready() -> void:
	add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	DialogueUI.register_root(self)
	visible = false
	portrait.visible = false

func show_box() -> void:
	visible = true

func hide_box() -> void:
	visible = false

# tex == null means "no portrait for this speaker" (narrator lines, etc).
func set_portrait(tex: Texture2D) -> void:
	portrait.texture = tex
	portrait.visible = tex != null
