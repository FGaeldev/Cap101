# achievements_panel.gd — Achievements: scrollable grid of cards, "unlocked /
# total" in the header. Locked cards show "???" so they don't spoil anything,
# the same rule the book's Achievements tab follows. Below them, a Collections
# section lists story keepsakes (data/collections.json), found by story flag.
extends "res://scripts/ui/menus/menu_panel.gd"

const COLUMNS := 3
## Icons at the sheet's own 24px.
const ACHIEVEMENT_ICON_SIZE := 24

var _grid: GridContainer
var _count: Label
var _collections_title: Label
var _collections_grid: GridContainer

func _init() -> void:
	super("Achievements")
	_count = MenuStyle.label("", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS)
	header_extra.add_child(_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 6)
	scroll.add_child(sections)
	sections.add_child(_grid)

	# Collections: keepsakes from the story, found by story flag.
	_collections_title = MenuStyle.label("", UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS)
	sections.add_child(_collections_title)
	_collections_grid = GridContainer.new()
	_collections_grid.columns = COLUMNS
	_collections_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collections_grid.add_theme_constant_override("h_separation", 6)
	_collections_grid.add_theme_constant_override("v_separation", 6)
	sections.add_child(_collections_grid)

func _on_show() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var unlocked_count := 0
	for ach in AchievementManager.achievements:
		var unlocked: bool = AchievementManager.is_unlocked(ach)
		if unlocked:
			unlocked_count += 1
		_grid.add_child(_make_card(ach, unlocked))
	_count.text = "%d / %d" % [unlocked_count, AchievementManager.achievements.size()]
	if AchievementManager.achievements.is_empty():
		_grid.add_child(MenuStyle.label("No achievements yet.", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED))

	for child in _collections_grid.get_children():
		child.queue_free()
	var items: Array = AchievementManager.collections
	_collections_title.visible = not items.is_empty()
	_collections_title.text = "Collections  %d / %d" % [AchievementManager.collected_count(), items.size()]
	for item in items:
		_collections_grid.add_child(_make_card(item, AchievementManager.is_collected(item), true))

## keepsake = a Collections item: a different icon and "Not found yet." when locked.
func _make_card(ach: Dictionary, unlocked: bool, keepsake: bool = false) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", MenuStyle.card_style(6))
	if not unlocked:
		card.modulate = Color(1, 1, 1, 0.6)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	vbox.add_child(top)
	var found_icon: int = MenuStyle.ICON_DONE if keepsake else MenuStyle.ICON_ACHIEVEMENTS
	var icon := MenuStyle.icon_rect(found_icon if unlocked else MenuStyle.ICON_LOCKED,
			MenuStyle.ICON_COLOR_GOLD if unlocked else MenuStyle.ICON_COLOR, ACHIEVEMENT_ICON_SIZE)
	top.add_child(icon)
	var title := MenuStyle.label(ach.get("title", "???") if unlocked else "???", UIThemeApplier.FONT_SIZE_S,
			UIThemeApplier.TEXT_EMPHASIS if unlocked else UIThemeApplier.TEXT_DISABLED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)

	var locked_text: String = "Not found yet." if keepsake else "Locked."
	var desc := MenuStyle.label(ach.get("description", "") if unlocked else locked_text, UIThemeApplier.FONT_SIZE_XS,
			UIThemeApplier.TEXT_DEFAULT if unlocked else UIThemeApplier.TEXT_DISABLED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 1  # let the card's width decide the wrap
	vbox.add_child(desc)
	return card
