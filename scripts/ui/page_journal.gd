# page_journal.gd — PageLeft for Journal (bucket_list) tab.
#
# Two sections, one scroll list: Quest Log (active + completed, from
# QuestManager/GameState) then Achievements (stub, from AchievementManager —
# derived state, see that autoload's header comment). Roadmap Phase A /
# GDD open-question decision: journal = quest log + achievement stub, both.
extends Control

@onready var list: VBoxContainer = $ScrollContainer/List

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")

## Called by BookUI right before this tab becomes visible.
func refresh() -> void:
	_rebuild()

func _rebuild() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	_add_header("Quest Log")
	_rebuild_quests()

	_add_header("Achievements")
	_rebuild_achievements()

func _rebuild_quests() -> void:
	if QuestManager.quests.is_empty():
		_add_meta_line("No quests yet.")
		return

	for quest_id in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[quest_id]
		var completed: bool = GameState.get_flag(q.get("completion_flag", ""))
		var is_active: bool = quest_id == QuestManager.active_quest
		_add_quest_row(q.get("title", quest_id), completed, is_active)

func _rebuild_achievements() -> void:
	if AchievementManager.achievements.is_empty():
		_add_meta_line("No achievements defined.")
		return

	for ach in AchievementManager.achievements:
		var unlocked: bool = AchievementManager.is_unlocked(ach)
		_add_achievement_row(ach.get("title", "???"), ach.get("description", ""), unlocked)

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
