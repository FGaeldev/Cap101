# page_journal.gd — Quest Log, PageLeft of the Journal (bucket_list) tab.
# Achievements moved to page_journal_achievements.gd on PageRight — was
# previously crammed into this same column, which is what caused overflow:
# two sections sharing one ~202px-tall half while the other half sat
# entirely empty. See BookUI.gd's bucket_list registration.
#
# Paginated — implements next_page()/prev_page()/has_next_page()/
# has_prev_page(), picked up generically by BookUI's bottom bar
# (BookUI.gd::_get_paginated_page()). Static "Quest Log" header sits outside
# the paginated list (not part of row packing) so it doesn't eat budget on
# every page — only page 1 needs it visually, but leaving it up throughout
# is simpler than tracking "is this page 1" and costs nothing since a single
# row type (quest rows only, now) makes the budget math trivial anyway.
#
# QUEST_ROW_HEIGHT is a fixed ceiling: title_label is clip_text=true (single
# line, trims instead of wrapping), so every row is the same height and
# QUESTS_PER_PAGE can be a flat division instead of guessing at wrap.
extends Control

@onready var header: Label = $Header
@onready var list: VBoxContainer = $List

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

# Header (~23px) taken off the ~202px page budget up front, once.
const LIST_HEIGHT_BUDGET := 179.0
const QUEST_ROW_HEIGHT := 22.0
const QUESTS_PER_PAGE := 8   # floor(179/22) = 8 — covers Phase C's planned ~12-quest scale in 2 pages

var _quest_ids: Array = []
var _offset: int = 0

func _ready() -> void:
	clip_contents = true
	header.text = "Quest Log"
	header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)

func refresh() -> void:
	_offset = 0
	_quest_ids = QuestManager.quests.keys()
	_render_page()

func next_page() -> void:
	if has_next_page():
		_offset += QUESTS_PER_PAGE
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_offset -= QUESTS_PER_PAGE
		_render_page()

func has_next_page() -> bool:
	return _offset + QUESTS_PER_PAGE < _quest_ids.size()

func has_prev_page() -> bool:
	return _offset > 0

func _render_page() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	if _quest_ids.is_empty():
		_add_meta_line("No quests yet.")
		return

	var page_end: int = mini(_offset + QUESTS_PER_PAGE, _quest_ids.size())
	for quest_id in _quest_ids.slice(_offset, page_end):
		var q: Dictionary = QuestManager.quests[quest_id]
		_add_quest_row(
			q.get("title", quest_id),
			GameState.get_flag(q.get("completion_flag", "")),
			quest_id == QuestManager.active_quest
		)

func _add_quest_row(title: String, completed: bool, is_active: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(row)

	var status := Label.new()
	status.text = "[x]" if completed else ("[>]" if is_active else "[ ]")
	status.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if completed else UIThemeApplier.TEXT_DEFAULT)
	status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	row.add_child(status)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED if completed else UIThemeApplier.TEXT_DEFAULT)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	row.add_child(title_label)

	_add_separator()

func _add_meta_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	list.add_child(label)

func _add_separator() -> void:
	var sep := HSeparator.new()
	var sep_style := StyleBoxTexture.new()
	sep_style.texture = LINE_TEXTURE
	sep_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	list.add_child(sep)
