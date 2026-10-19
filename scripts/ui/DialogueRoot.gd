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
@onready var text_column: VBoxContainer = $Layout/DialoguePanel/Margin/TextColumn

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

## Recalculate bottom-anchored panel height after dynamic dialogue/menu visibility changes.
func refresh_content_size() -> void:
	_fit_to_content.call_deferred()

## Keep full viewport width; size panel for whichever dialogue content is visible.
func _fit_to_content() -> void:
	if not is_node_ready():
		return

	var menu := text_column.get_node_or_null("NPCInteractionMenu") as Control
	var dialogue_height := dialogue_box.get_combined_minimum_size().y if dialogue_box.visible else 0.0
	var choice_height := choice_box.get_combined_minimum_size().y if choice_box.visible else 0.0
	var content_height := maxf(dialogue_height + COLUMN_SEPARATION + choice_height, 3.0 * MIN_CHOICE_HEIGHT + 2.0 * CHOICE_SEPARATION)
	if menu != null and menu.visible:
		content_height = maxf(content_height, menu.get_combined_minimum_size().y)
	var panel_height := content_height + PANEL_VERTICAL_MARGINS

	# Custom minimum affects only vertical sizing; horizontal anchors remain full-screen.
	dialogue_panel.custom_minimum_size.y = panel_height
	var required_height := portrait_row.get_combined_minimum_size().y + panel_height + LAYOUT_SEPARATION
	offset_top = -maxf(layout.get_combined_minimum_size().y, required_height)

## Hide portrait when speaker has no portrait; otherwise align by speaker role.
func set_portrait(tex: Texture2D, speaker: String) -> void:
	portrait.texture = tex
	portrait.visible = tex != null
	if tex != null:
		var is_player := speaker.strip_edges().to_lower() == "[player]"
		left_spacer.visible = not is_player
		right_spacer.visible = is_player
	_fit_to_content.call_deferred()
