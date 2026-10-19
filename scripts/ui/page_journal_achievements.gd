# page_journal_achievements.gd — Achievements tab. Both pages.
#
# Uses the shared Header + List layout (scenes/ui/page_list_column.tscn) via
# PageListColumn: left = primary ("Achievements" header, owns pagination),
# right = partner (continues the list). Was previously the right half of the
# Journal tab, unpaginated; now its own tab with two-column pagination, so
# AchievementManager can grow past one page without a BookUI change.
#
# ACHIEVEMENT_ROW_HEIGHT is a fixed ceiling: description is capped to 1 line
# (AUTOWRAP_OFF + clip_text + ellipsis overrun) so every row is the same
# height — locked achievements show "???"/"Locked." instead of the real
# title/description, both intentional (don't spoil) and convenient (short,
# fixed length, never risks wrapping).
extends PageListColumn

## ~202px page - 32px Header min height (page_list_column.tscn) = ~170px.
const LIST_HEIGHT_BUDGET := 170.0
const ACHIEVEMENT_ROW_HEIGHT := 35.0  # title line + desc capped to 1 line + separator

func _get_header_text() -> String:
	return "Achievements" if partner_column != null else ""

func _get_items() -> Array:
	return AchievementManager.achievements

func rows_per_column() -> int:
	return int(LIST_HEIGHT_BUDGET / ACHIEVEMENT_ROW_HEIGHT)   # 4 -> 8 per spread

func _get_empty_text() -> String:
	return "No achievements defined."

func _add_item_row(ach) -> void:
	var unlocked: bool = AchievementManager.is_unlocked(ach)
	var row := add_status_row(unlocked, false, ach.get("title", "???") if unlocked else "???", not unlocked)
	# Locked status/title read as disabled; unlocked title pops in emphasis.
	var status: Label = row.get_child(0)
	var title_label: Label = row.get_child(1)
	status.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	if unlocked:
		title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)

	var desc_label := Label.new()
	desc_label.text = ach.get("description", "") if unlocked else "Locked."
	desc_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	desc_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	desc_label.clip_text = true
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.add_child(desc_label)

	add_separator()
