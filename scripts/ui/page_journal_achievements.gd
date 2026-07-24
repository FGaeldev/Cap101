# page_journal_achievements.gd — Achievements, PageRight of the Journal
# (bucket_list) tab. Split out from page_journal.gd (which used to cram
# both quest log AND achievements into PageLeft alone, causing overflow) —
# see BookUI.gd's bucket_list registration.
#
# NOT paginated — at current content scale (5 stub achievements, see
# AchievementManager) the whole list fits inside the ~179px list budget
# (5 * ACHIEVEMENT_ROW_HEIGHT ≈ 175px). If AchievementManager.achievements
# grows past what fits, this needs the same next_page()/prev_page()/
# has_next_page()/has_prev_page() treatment as page_journal.gd — but note
# BookUI's bottom bar only drives ONE paginated side per tab
# (_get_paginated_page() checks "page" first, then "page_right" — it can't
# drive both independently). Quest Log already owns "page"/pagination for
# this tab, so making Achievements paginated too needs a BookUI change, not
# just a method here — flag before doing it, don't just add the methods.
#
# ACHIEVEMENT_ROW_HEIGHT is a fixed ceiling: description is capped to 1 line
# (AUTOWRAP_OFF + clip_text + ellipsis overrun) so every row is the same
# height — locked achievements show "???"/"Locked." instead of the real
# title/description, both intentional (don't spoil) and convenient (short,
# fixed length, never risks wrapping).
extends Control

@onready var header: Label = $Header
@onready var list: VBoxContainer = $List

const LINE_TEXTURE := preload("res://assets/ui/book/line.png")
const ACHIEVEMENT_ROW_HEIGHT := 35.0  # title line + desc capped to 1 line + separator

func _ready() -> void:
	clip_contents = true
	header.text = "Achievements"
	header.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	header.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)

func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.free()

	if AchievementManager.achievements.is_empty():
		_add_meta_line("No achievements defined.")
		return

	for ach in AchievementManager.achievements:
		var unlocked: bool = AchievementManager.is_unlocked(ach)
		_add_achievement_row(ach.get("title", "???"), ach.get("description", ""), unlocked)

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
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	top_row.add_child(title_label)

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
