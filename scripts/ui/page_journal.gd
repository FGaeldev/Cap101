# page_journal.gd — Quest Log, Journal (bucket_list) tab. Both pages.
#
# Uses the shared Header + List layout (scenes/ui/page_list_column.tscn) via
# PageListColumn. BookUI instantiates two columns: left = primary ("Quest Log"
# header, owns pagination), right = partner (continues the same list). See
# page_list_column.gd for the two-column contract.
#
# Achievements moved to their own tab (page_journal_achievements.gd) and the
# dev warp/cutscene menu to its own tab (page_dev.gd) — this page is quests
# only now.
#
# QUEST_ROW_HEIGHT is a fixed ceiling: title label is clip_text=true (single
# line, trims instead of wrapping), so every row is the same height and
# rows_per_column() can be a flat division instead of guessing at wrap.
extends PageListColumn

## ~202px page - 32px Header min height (page_list_column.tscn) = ~170px.
const LIST_HEIGHT_BUDGET := 170.0
const QUEST_ROW_HEIGHT := 22.0   # status/title row + separator

func _get_header_text() -> String:
	return "Quest Log" if partner_column != null else ""

func _get_items() -> Array:
	return QuestManager.quests.keys()

func rows_per_column() -> int:
	return int(LIST_HEIGHT_BUDGET / QUEST_ROW_HEIGHT)   # 7 -> 14 per spread

func _get_empty_text() -> String:
	return "No quests yet."

func _add_item_row(quest_id) -> void:
	var q: Dictionary = QuestManager.quests[quest_id]
	var completed: bool = GameState.get_flag(q.get("completion_flag", ""))
	add_status_row(completed, quest_id in QuestManager.active_quests, q.get("title", quest_id), completed)
	add_separator()
