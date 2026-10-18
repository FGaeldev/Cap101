# DialogueRoot.gd — portrait sits above, not inside, the dialogue panel.
# Player portraits align left; NPC portraits align right.
extends Control

@onready var portrait: TextureRect = $Layout/PortraitRow/Portrait
@onready var left_spacer: Control = $Layout/PortraitRow/LeftSpacer
@onready var right_spacer: Control = $Layout/PortraitRow/RightSpacer
@onready var dialogue_panel: PanelContainer = $Layout/DialoguePanel

func _ready() -> void:
	dialogue_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	DialogueUI.register_root(self)
	visible = false
	portrait.visible = false

func show_box() -> void:
	visible = true

func hide_box() -> void:
	visible = false

## Hide portrait when speaker has no portrait; otherwise align by speaker role.
func set_portrait(tex: Texture2D, speaker: String) -> void:
	portrait.texture = tex
	portrait.visible = tex != null
	if tex == null:
		return

	var is_player := speaker.strip_edges().to_lower() == "[player]"
	left_spacer.visible = not is_player
	right_spacer.visible = is_player
