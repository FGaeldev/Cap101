# page_journal.gd — PageLeft for Journal (bucket_list) tab.
#
# Quest Log (active + completed, from QuestManager/GameState) then
# Achievements (stub, from AchievementManager — derived state, see that
# autoload's header comment). Roadmap Phase A / GDD open-question decision:
# journal = quest log + achievement stub, both.
#
# Paginated, not scrolled — implements next_page()/prev_page()/
# has_next_page()/has_prev_page(), picked up generically by BookUI's bottom
# bar (BookUI.gd::_update_bottom_bar()). Builds one flat row list (headers +
# quest rows + achievement rows) and paginates over that. ROWS_PER_PAGE is a
# placeholder count, not pixel-measured — current content (1 quest, 5
# achievements) fits one page; revisit once Phase C scales quest count up
# and a header could land mid-page-break.
extends Control

@onready var list: VBoxContainer = $List

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")
const ROWS_PER_PAGE := 8

var _rows: Array = []  # flat: [{type:"header"/"quest"/"achievement"/"meta", ...}]
var _offset: int = 0

func refresh() -> void:
	_offset = 0
	_rebuild_rows()
	_render_page()

func next_page() -> void:
	if has_next_page():
		_offset += ROWS_PER_PAGE
		_render_page()

func prev_page() -> void:
	if has_prev_page():
		_offset -= ROWS_PER_PAGE
		_render_page()

func has_next_page() -> bool:
	return _offset + ROWS_PER_PAGE < _rows.size()

func has_prev_page() -> bool:
	return _offset > 0

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

func _render_page() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	var page_end: int = mini(_offset + ROWS_PER_PAGE, _rows.size())
	var page_slice: Array = _rows.slice(_offset, page_end)
	for row in page_slice:
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
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	top_row.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = description if unlocked else "Locked."
	desc_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	desc_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
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
