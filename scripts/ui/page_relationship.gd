# page_relationship.gd — one column of up to MAX_ROWS NPC rows (portrait,
# name, rapport hearts, patience bar). Same script instantiated TWICE by
# BookUI — once per page-half of the spread. The PRIMARY instance (the one
# with partner_column assigned) owns pagination for both halves; the
# secondary instance is purely passive, fed via show_entries().
extends Control

const HeartsDisplayScene := preload("res://scenes/ui/hearts_display.tscn")
const MeterBarScene := preload("res://scenes/ui/meter_bar.tscn")

const MAX_ROWS := 4          # per column (per page-half)
const PAGE_SIZE := MAX_ROWS * 2  # 2 cols x 4 rows = 8 NPCs visible per "spread"

# Portrait height per row, fixed rather than measured at runtime.
# 202px row_list height / MAX_ROWS(4) - 8 padding ≈ 42px.
# Depends on book_ui.tscn's Spread/page anchors — update by hand if those change.
const PORTRAIT_HEIGHT := 42.0

@onready var row_list: VBoxContainer = $RowList

## Set externally by BookUI right after both column instances exist.
## Only the primary/left instance gets this — leave null on the secondary.
var partner_column: Control = null

var _hearts_by_npc: Dictionary = {}
var _bars_by_npc: Dictionary = {}
var _all_npc_ids: Array[String] = []
var _offset: int = 0

func _ready() -> void:
	GameState.rapport_changed.connect(_on_rapport_changed)
	GameState.patience_changed.connect(_on_patience_changed)

## Called by BookUI's generic page-refresh hook. No-op on the secondary
## instance (partner_column null) — its content only ever arrives via
## show_entries() from the primary's _render_page().
func refresh() -> void:
	if partner_column == null:
		return
	_all_npc_ids = CharacterRegistry.get_all_speaker_ids()
	_offset = 0
	_render_page()

func next_page() -> void:
	if has_next_page():
		_offset += PAGE_SIZE
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_offset -= PAGE_SIZE
		_render_page()

func has_next_page() -> bool:
	return _offset + PAGE_SIZE < _all_npc_ids.size()

func has_prev_page() -> bool:
	return _offset > 0

func _render_page() -> void:
	var left_end: int = mini(_offset + MAX_ROWS, _all_npc_ids.size())
	var right_end: int = mini(_offset + PAGE_SIZE, _all_npc_ids.size())
	var left_slice: Array[String] = _all_npc_ids.slice(_offset, left_end)
	var right_slice: Array[String] = _all_npc_ids.slice(left_end, right_end)
	show_entries(left_slice)
	if partner_column:
		partner_column.show_entries(right_slice)

## Public — also called directly by the primary on its partner.
func show_entries(npc_ids: Array[String]) -> void:
	for child in row_list.get_children():
		row_list.remove_child(child)
		child.free()
	_hearts_by_npc.clear()
	_bars_by_npc.clear()
	for npc_id in npc_ids:
		_add_row(npc_id)

func _add_row(npc_id: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_list.add_child(row)

	var portrait := TextureRect.new()
	var tex: Texture2D = CharacterRegistry.get_portrait(npc_id)
	portrait.texture = tex
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if tex:
		var aspect: float = float(tex.get_width()) / float(tex.get_height())
		var target_size := Vector2(PORTRAIT_HEIGHT * aspect, PORTRAIT_HEIGHT)
		portrait.custom_minimum_size = target_size
		portrait.custom_maximum_size = target_size
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
	info.add_child(hearts)
	hearts.set_value(GameState.get_rapport(npc_id))
	_hearts_by_npc[npc_id] = hearts

	var patience_label := Label.new()
	patience_label.text = "Patience"
	patience_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	patience_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	info.add_child(patience_label)

	var bar := MeterBarScene.instantiate()
	info.add_child(bar)
	bar.set_value(GameState.get_patience(npc_id), GameState.PATIENCE_MAX)
	_bars_by_npc[npc_id] = bar

func _on_rapport_changed(npc_id: String, value: float) -> void:
	if _hearts_by_npc.has(npc_id):
		_hearts_by_npc[npc_id].set_value(value)

func _on_patience_changed(npc_id: String, value: int) -> void:
	if _bars_by_npc.has(npc_id):
		_bars_by_npc[npc_id].set_value(value, GameState.PATIENCE_MAX)
