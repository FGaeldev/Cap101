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
#
# --- Dev Skip Menu ---
# When GameState.dev_mode is on (Settings tab checkbox), this page opens on
# a hidden warp menu instead of the quest list — treated as a virtual
# "page -1" ahead of the normal paginated quest content, reachable/leavable
# through the same prev/next arrows BookUI already wires up generically, no
# new UI chrome needed. Off (default): behaves exactly as before, dev page
# never shows and never costs a rendered node.
#
# DEV_WARP_TARGETS is a hardcoded array, not a folder scan — required by the
# Android PCK rule (DirAccess silently returns zero files in exported
# builds, TDD §9 item 1). Add new playable levels here by hand as they land.
extends Control

@onready var header: Label = $Header
@onready var list: VBoxContainer = $List
@onready var dev_page: Control = $DevSkipPage
@onready var dev_header: Label = $DevSkipPage/DevHeader
@onready var dev_list: VBoxContainer = $DevSkipPage/DevList

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

# Header (~23px) taken off the ~202px page budget up front, once.
const LIST_HEIGHT_BUDGET := 179.0
const QUEST_ROW_HEIGHT := 22.0
const QUESTS_PER_PAGE := 8   # floor(179/22) = 8 — covers Phase C's planned ~12-quest scale in 2 pages

# {label, scene_path} — only scenes with their own Player node belong here;
# sub-rooms preloaded/embedded by another scene (e.g. usa_home_indoors.tscn,
# lives inside scene01.tscn) are not valid standalone warp targets.
const DEV_WARP_TARGETS := [
	{"label": "Ch1 — Village (scene01)", "scene_path": "res://scenes/world/scene01.tscn"},
	{"label": "Ch1 — Scene 2 (Airport)", "scene_path": "res://scenes/world/scene_2.tscn"},
]

var _quest_ids: Array = []
var _offset: int = 0
var _dev_mode_active: bool = false
var _on_dev_page: bool = false

func _ready() -> void:
	clip_contents = true
	header.text = "Quest Log"
	header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	dev_header.text = "DEV: Skip to Scene"
	dev_header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	dev_header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	_build_dev_buttons()

func refresh() -> void:
	# Re-read every open, not just once — Settings' DevModeToggle can flip
	# this between visits while BookUI itself stays alive (page instances
	# are never re-created, TDD §8 page pattern).
	_dev_mode_active = GameState.dev_mode
	_offset = 0
	_quest_ids = QuestManager.quests.keys()
	_on_dev_page = _dev_mode_active   # land on the warp menu first if enabled
	_render_page()

func next_page() -> void:
	if _on_dev_page:
		_on_dev_page = false
		_render_page()
		return
	if has_next_page():
		_offset += QUESTS_PER_PAGE
		_render_page()

func prev_page() -> void:
	if _on_dev_page:
		return
	if _dev_mode_active and _offset == 0:
		_on_dev_page = true
		_render_page()
		return
	if has_prev_page():
		_offset -= QUESTS_PER_PAGE
		_render_page()

func has_next_page() -> bool:
	if _on_dev_page:
		return true   # quest list is always reachable from the dev page, even if empty
	return _offset + QUESTS_PER_PAGE < _quest_ids.size()

func has_prev_page() -> bool:
	if _on_dev_page:
		return false
	if _dev_mode_active and _offset == 0:
		return true   # step back onto the dev page
	return _offset > 0

func _render_page() -> void:
	dev_page.visible = _on_dev_page
	list.visible = not _on_dev_page
	header.visible = not _on_dev_page
	if _on_dev_page:
		return

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
			quest_id in QuestManager.active_quests
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

## Built once in _ready() from the hardcoded DEV_WARP_TARGETS array — not
## rebuilt per-refresh, buttons never change at runtime.
func _build_dev_buttons() -> void:
	for target in DEV_WARP_TARGETS:
		var btn := Button.new()
		btn.text = target["label"]
		UIThemeApplier.apply_button_theme(btn, "secondary")
		btn.pressed.connect(_on_dev_warp_pressed.bind(target["scene_path"]))
		dev_list.add_child(btn)

## Mirrors page_settings.gd::_on_quit_pressed()'s leave-scene sequence:
## abort any in-flight cutscene first (TDD §9 item 8 — mid-cutscene quit
## softlock rule applies to any "leave the game" path, warping included),
## close BookUI and unpause, then swap scenes directly. No save — this is a
## dev shortcut, not a real save-point transition.
func _on_dev_warp_pressed(scene_path: String) -> void:
	CutsceneManager.abort()
	BookUI.close()
	get_tree().change_scene_to_file(scene_path)
