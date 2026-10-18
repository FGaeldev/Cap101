# DialogueRoot.gd — compact bottom dialogue UI with portrait above the panel.
# Root height tracks content minimum size; panel never fills unused screen space.
extends Control

@onready var layout: VBoxContainer = $Layout
@onready var portrait: TextureRect = $Layout/PortraitRow/Portrait
@onready var left_spacer: Control = $Layout/PortraitRow/LeftSpacer
@onready var right_spacer: Control = $Layout/PortraitRow/RightSpacer
@onready var dialogue_panel: PanelContainer = $Layout/DialoguePanel

func _ready() -> void:
	dialogue_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	DialogueUI.register_root(self)
	visible = false
	portrait.visible = false
	_fit_to_content()

func show_box() -> void:
	visible = true
	_fit_to_content.call_deferred()

func hide_box() -> void:
	visible = false

## Fit root height to speaker, prompt, and visible choices while keeping bottom anchor.
func _fit_to_content() -> void:
	if not is_node_ready():
		return
	layout.reset_size()
	var required_height: float = layout.get_combined_minimum_size().y
	offset_top = -required_height

## Hide portrait when speaker has no portrait; otherwise align by speaker role.
func set_portrait(tex: Texture2D, speaker: String) -> void:
	portrait.texture = tex
	portrait.visible = tex != null
	if tex != null:
		var is_player := speaker.strip_edges().to_lower() == "[player]"
		left_spacer.visible = not is_player
		right_spacer.visible = is_player
	_fit_to_content.call_deferred()
