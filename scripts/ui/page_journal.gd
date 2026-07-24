# page_journal.gd — PageLeft for Journal (bucket_list) tab.
#
# Quest Log (active + completed, from QuestManager/GameState) then
# Achievements (stub, from AchievementManager — derived state, see that
# autoload's header comment). Roadmap Phase A / GDD open-question decision:
# journal = quest log + achievement stub, both.
#
# Paginated, not scrolled — implements next_page()/prev_page()/
# has_next_page()/has_prev_page(), picked up generically by BookUI's bottom
# bar (BookUI.gd::_update_bottom_bar()).
#
# PAGE_HEIGHT_BUDGET is measured, not guessed: Spread anchors in book_ui.tscn
# give ~210px tall page halves at 512x288 viewport, PageJournal's own
# 0.02-0.98 anchor takes ~4% off each side -> ~202px content height. Same
# budget page_dictionary.gd and page_relationship.gd use — same page.
#
# Row heights differ by type (header/quest/achievement/meta), so a flat
# ROWS_PER_PAGE count can't work — a page of achievement rows (title + desc
# line) is taller than a page of quest rows (single line). Instead, pages
# are packed by ACCUMULATED height against the real budget (_rebuild_pages),
# computed once per refresh. Each row type is capped to a fixed max line
# count (title/desc labels get max_lines_visible + ellipsis overrun) so the
# height constants below are true ceilings, not averages — that's what makes
# packing-by-constant safe instead of another guess. clip_contents is still
# on as a hard backstop.
extends Control

@onready var list: VBoxContainer = $List

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

const PAGE_HEIGHT_BUDGET := 202.0
const HEADER_HEIGHT := 23.0        # FONT_SIZE_L line + separator
const QUEST_ROW_HEIGHT := 22.0     # FONT_SIZE_M single line (capped) + separator
const ACHIEVEMENT_ROW_HEIGHT := 35.0  # title line + desc capped to 1 line + separator
const META_HEIGHT := 13.0          # FONT_SIZE_S single line, no separator

var _rows: Array = []          # flat: [{type:"header"/"quest"/"achievement"/"meta", ...}]
var _page_starts: Array = []   # row index each page begins at
var _current_page: int = 0

func _ready() -> void:
	clip_contents = true

func refresh() -> void:
	_current_page = 0
	_rebuild_rows()
	_rebuild_pages()
	_render_page()

func next_page() -> void:
	if has_next_page():
		_current_page += 1
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_current_page -= 1
		_render_page()

func has_next_page() -> bool:
	return _current_page + 1 < _page_starts.size()

func has_prev_page() -> bool:
	return _current_page > 0

func _rebuild_rows() -> void:
	_rows.clear()
	_rows.append({"type": "header", "text": "Quest Log"})

	if QuestManager.quests.is_empty():
		_rows.append({"type": "meta", "text": "No quests yet."})
	else:
		for quest_id in QuestManager.quests:
			var q: Dictionary = QuestManager.quests[quest_id]
			_rows.append({
				"type": "quest",
				"title": q.get("title", quest_id),
				"completed": GameState.get_flag(q.get("completion_flag", "")),
				"active": quest_id == QuestManager.active_quest
			})

	_rows.append({"type": "header", "text": "Achievements"})

	if AchievementManager.achievements.is_empty():
		_rows.append({"type": "meta", "text": "No achievements defined."})
	else:
		for ach in AchievementManager.achievements:
			var unlocked: bool = AchievementManager.is_unlocked(ach)
			_rows.append({
				"type": "achievement",
				"title": ach.get("title", "???"),
				"description": ach.get("description", ""),
				"unlocked": unlocked
			})

## Greedy pack: walk _rows accumulating each type's fixed height ceiling,
## start a new page the moment the next row would exceed budget. A single
## row taller than the whole budget still gets its own page rather than
## looping forever.
func _rebuild_pages() -> void:
	_page_starts.clear()
	if _rows.is_empty():
		_page_starts.append(0)
		return

	_page_starts.append(0)
	var accumulated := 0.0
	for i in range(_rows.size()):
		var h: float = _row_height(_rows[i]["type"])
		if accumulated + h > PAGE_HEIGHT_BUDGET and accumulated > 0.0:
			_page_starts.append(i)
			accumulated = 0.0
		accumulated += h

func _row_height(type: String) -> float:
	match type:
		"header": return HEADER_HEIGHT
		"quest": return QUEST_ROW_HEIGHT
		"achievement": return ACHIEVEMENT_ROW_HEIGHT
		"meta": return META_HEIGHT
		_: return QUEST_ROW_HEIGHT

func _render_page() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	var start: int = _page_starts[_current_page]
	var end: int = _page_starts[_current_page + 1] if _current_page + 1 < _page_starts.size() else _rows.size()
	for row in _rows.slice(start, end):
		match row["type"]:
			"header":
				_add_header(row["text"])
			"quest":
				_add_quest_row(row["title"], row["completed"], row["active"])
			"achievement":
				_add_achievement_row(row["title"], row["description"], row["unlocked"])
			"meta":
				_add_meta_line(row["text"])

func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	list.add_child(label)
	_add_separator()

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
	title_label.clip_text = true   # single line by design (QUEST_ROW_HEIGHT assumes it) — long titles trim, not wrap
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED if completed else UIThemeApplier.TEXT_DEFAULT)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	row.add_child(title_label)

	_add_separator()

func _add_achievement_row(title: String, description: String, unlocked: bool) -> void:
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(top_row)

	var status := Label.new()
	status.text = "[x]" if unlocked else "[ ]"
	status.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	status.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	top_row.add_child(status)

	var title_label := Label.new()
	title_label.text = title if unlocked else "???"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	top_row.add_child(title_label)

	# Capped to 1 line + ellipsis — this is what makes ACHIEVEMENT_ROW_HEIGHT
	# a true ceiling instead of "however long the description happens to be."
	var desc_label := Label.new()
	desc_label.text = description if unlocked else "Locked."
	desc_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	desc_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	desc_label.clip_text = true
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(desc_label)

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
