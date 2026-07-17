# page_relationship.gd — Relationship tab content: one row per NPC
# (portrait, name, rapport hearts, patience bar). Lives on PageLeft.
# Roster comes from CharacterRegistry, not a separate list — same NPCs
# already used for dialogue portraits are the ones tracked here.
extends Control

@onready var npc_list: VBoxContainer = $ScrollContainer/NpcList

const HeartsDisplayScene := preload("res://scenes/ui/hearts_display.tscn")
const MeterBarScene := preload("res://scenes/ui/meter_bar.tscn")

var _hearts_by_npc: Dictionary = {}   # npc_id -> HeartsDisplay instance
var _bars_by_npc: Dictionary = {}     # npc_id -> MeterBar instance

func _ready() -> void:
	GameState.rapport_changed.connect(_on_rapport_changed)
	GameState.patience_changed.connect(_on_patience_changed)

## Called by BookUI.switch_tab() right before this page becomes visible.
func refresh() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in npc_list.get_children():
		npc_list.remove_child(child)
		child.free()
	_hearts_by_npc.clear()
	_bars_by_npc.clear()

	for npc_id in CharacterRegistry.get_all_speaker_ids():
		_add_row(npc_id)

func _add_row(npc_id: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_list.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = CharacterRegistry.get_portrait(npc_id)
	portrait.custom_minimum_size = Vector2(24, 24)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = npc_id
	name_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	name_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	info.add_child(name_label)

	var hearts := HeartsDisplayScene.instantiate()
	hearts.set_value(GameState.get_rapport(npc_id))
	_hearts_by_npc[npc_id] = hearts
	info.add_child(hearts)

	var patience_label := Label.new()
	patience_label.text = "Patience"
	patience_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	patience_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	info.add_child(patience_label)

	var bar := MeterBarScene.instantiate()
	bar.set_value(GameState.get_patience(npc_id), GameState.PATIENCE_MAX)
	_bars_by_npc[npc_id] = bar
	info.add_child(bar)

func _on_rapport_changed(npc_id: String, value: float) -> void:
	if _hearts_by_npc.has(npc_id):
		_hearts_by_npc[npc_id].set_value(value)

func _on_patience_changed(npc_id: String, value: int) -> void:
	if _bars_by_npc.has(npc_id):
		_bars_by_npc[npc_id].set_value(value, GameState.PATIENCE_MAX)
