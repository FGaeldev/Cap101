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
	portrait_row.visible = false
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

	# Measure the visible children actually rendered in TextColumn. NPC action
	# menus are inserted dynamically, so measuring only DialogueBox/ChoiceBox
	# misses their minimum height and can leave the panel/root at stale sizes.
	var column_height := 0.0
	for child in $Layout/DialoguePanel/Margin/TextColumn.get_children():
		if child is Control and child.visible:
			column_height += child.get_combined_minimum_size().y

	var visible_controls := 0
	for child in $Layout/DialoguePanel/Margin/TextColumn.get_children():
		if child is Control and child.visible:
			visible_controls += 1
	if visible_controls > 1:
		column_height += COLUMN_SEPARATION * float(visible_controls - 1)

	# Include the PanelContainer/MarginContainer theme margins in measured height.
	var panel_style := dialogue_panel.get_theme_stylebox("panel")
	var panel_vertical_margins := panel_style.get_minimum_size().y if panel_style else 0.0
	var margin_container := $Layout/DialoguePanel/Margin as MarginContainer
	var margin_vertical := float(margin_container.get_theme_constant("margin_top")) + float(margin_container.get_theme_constant("margin_bottom"))
	var panel_height := column_height + panel_vertical_margins + margin_vertical

	# Portrait occupies its own row only when actual portrait art exists.
	var portrait_height := portrait_row.get_combined_minimum_size().y if portrait_row.visible else 0.0
	var required_height := portrait_height + panel_height
	if portrait_row.visible:
		required_height += LAYOUT_SEPARATION

	# Explicitly size the bottom-anchored root and its panel. Never let the
	# full-rect VBoxContainer or a hidden/expand child dictate viewport height.
	dialogue_panel.custom_minimum_size.y = panel_height
	custom_minimum_size.y = required_height
	offset_top = -required_height
	layout.offset_top = 0.0
	layout.offset_bottom = 0.0

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
