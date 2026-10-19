# DialogueRoot.gd — full-width bottom dialogue UI with portrait above the panel.
# Keep a minimum panel height for the speaker, prompt, and three choice rows.
extends Control

const MIN_CHOICE_HEIGHT: float = 24.0
const CHOICE_SEPARATION: float = 3.0
const PANEL_VERTICAL_MARGINS: float = 6.0
const COLUMN_SEPARATION: float = 2.0
const LAYOUT_SEPARATION: float = 6.0

@onready var layout: VBoxContainer = $Layout
@onready var portrait_row: HBoxContainer = $Layout/PortraitRow
@onready var portrait: TextureRect = $Layout/PortraitRow/Portrait
@onready var left_spacer: Control = $Layout/PortraitRow/LeftSpacer
@onready var right_spacer: Control = $Layout/PortraitRow/RightSpacer
@onready var dialogue_panel: PanelContainer = $Layout/DialoguePanel
@onready var dialogue_box: PanelContainer = $Layout/DialoguePanel/Margin/TextColumn/DialogueBox
@onready var choice_box: PanelContainer = $Layout/DialoguePanel/Margin/TextColumn/ChoiceBox

func _ready() -> void:
	dialogue_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	DialogueUI.register_root(self)
	visible = false
	portrait.visible = false
	_fit_to_content()

func show_box() -> void:
	visible = true
	refresh_layout()

## Recalculate panel height after dialogue text or choice visibility changes.
func refresh_layout() -> void:
	_fit_to_content.call_deferred()

func hide_box() -> void:
	visible = false

## Keep full viewport width; calculate bottom-anchored height from content and a three-choice minimum.
func _fit_to_content() -> void:
	if not is_node_ready():
		return

	var minimum_choice_height := 3.0 * MIN_CHOICE_HEIGHT + 2.0 * CHOICE_SEPARATION
	# Hidden ChoiceBox must not reserve three rows or stretch into a blank panel.
	var choice_height := 0.0
	var column_separation := 0.0
	if choice_box.visible:
		var visible_choice_height := choice_box.get_combined_minimum_size().y
		choice_height = maxf(minimum_choice_height, visible_choice_height)
		column_separation = COLUMN_SEPARATION
	var dialogue_height := dialogue_box.get_combined_minimum_size().y
	var panel_height := dialogue_height + column_separation + choice_height + PANEL_VERTICAL_MARGINS

	# Custom minimum affects only vertical sizing; horizontal anchors remain full-screen.
	dialogue_panel.custom_minimum_size.y = panel_height
	# Do not use Layout's combined minimum: its expand-fill choice child can
	# report the old full-height minimum even after it is hidden. That pins the
	# root to its scene's 200px fallback and leaves a huge empty dialogue panel.
	var portrait_height := portrait_row.get_combined_minimum_size().y if portrait_row.visible else 0.0
	var required_height := portrait_height + panel_height
	if portrait_row.visible:
		required_height += LAYOUT_SEPARATION
	custom_minimum_size.y = required_height
	offset_top = -required_height

## Hide portrait when speaker has no portrait; otherwise align by speaker role.
func set_portrait(tex: Texture2D, speaker: String) -> void:
	portrait.texture = tex
	portrait.visible = tex != null
	# Hide entire row when portrait art is absent; hidden TextureRect alone can
	# still leave container sizing artifacts on some viewport/layout states.
	portrait_row.visible = tex != null
	if tex != null:
		var is_player := speaker.strip_edges().to_lower() == "[player]"
		left_spacer.visible = not is_player
		right_spacer.visible = is_player
	_fit_to_content.call_deferred()
