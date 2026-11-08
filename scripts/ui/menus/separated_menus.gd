# separated_menus.gd — the separated menus: a pause menu plus one full-screen
# panel per feature, shown by BookUI in place of the book while
# BookUI.separate_menus is on (dev menu switch, saved in user://settings.cfg).
#
# Lives as a child of the BookUI CanvasLayer, so everything that already checks
# BookUI.visible, calls BookUI.close() or BookUI.open("<tab>") keeps working
# unchanged. BookUI only creates this node the first time it is needed; with
# the switch off it never exists.
#
# Panels reuse the book's own page scenes where they fit (Settings, Dictionary,
# Calendar, Map, Dev); Quests and Achievements have their own scripts.
#
# Navigation: a panel opened from the pause menu goes back to it; a panel
# opened straight from the HUD (Map, Dictionary, clock, quest panel) closes.
extends Control

const MenuStyle := preload("res://scripts/ui/menus/menu_style.gd")
const MenuPanel := preload("res://scripts/ui/menus/menu_panel.gd")
const QuestsPanel := preload("res://scripts/ui/menus/quests_panel.gd")
const AchievementsPanel := preload("res://scripts/ui/menus/achievements_panel.gd")
const DevPanel := preload("res://scripts/ui/menus/dev_panel.gd")
const ConfirmPopupScene := preload("res://scenes/ui/confirm_popup.tscn")

const PageSettingsScene := preload("res://scenes/ui/page_settings.tscn")
const PageDictionaryListScene := preload("res://scenes/ui/page_dictionary.tscn")
const PageDictionaryFilterScene := preload("res://scenes/ui/page_dictionary_filter.tscn")
const PageMapScene := preload("res://scenes/ui/page_map.tscn")
const PageCalendarScript := preload("res://scripts/ui/page_calendar.gd")
const PageCalendarEventsScript := preload("res://scripts/ui/page_calendar_events.gd")

## BookUI tab ids -> what opens here. Relationship is hidden for now and falls
## back to the pause menu.
const TAB_TO_PANEL := {
	"settings": "pause",
	"relationship": "pause",
	"bucket_list": "quests",
	"achievements": "achievements",
	"dictionary": "dictionary",
	"map": "map",
	"calendar": "calendar",
	"dev": "dev",
}
## Size of the book's map spread; page_map.tscn's markers are placed in pixels for it.
const MAP_SIZE := Vector2(616, 289)
const PAUSE_WIDTH := 190.0
## Month grid in the one-piece Calendar: header, weekdays, 6 weeks, dev skip.
const CALENDAR_GRID_SIZE := Vector2(340, 212)

## BookUI routes its exit-to-menu confirm through this while the menus show.
var confirm_popup: ConfirmPopup

var _pause: Control
var _panels: Dictionary = {}  # panel id -> MenuPanel
var _current: String = ""
var _from_pause: bool = false

var _tier_label: Label
var _tier_count: Label
var _tier_bar: ProgressBar
var _tier_hint: Label
var _dev_btn: Button
var _dict_filter: Control
var _dict_list: Control
var _settings_page: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)  # also stops clicks from reaching the world underneath
	_build_pause()
	_build_panels()
	confirm_popup = ConfirmPopupScene.instantiate()
	add_child(confirm_popup)

## Entry point from BookUI.open(tab).
func open(tab: String) -> void:
	visible = true
	var target: String = TAB_TO_PANEL.get(tab, "pause")
	if target == "pause" and BookUI.is_main_menu_context():
		target = "settings"  # main menu's Settings button: nothing to pause
	if target == "dev" and not GameState.dev_mode:
		target = "pause"
	_from_pause = false
	_show(target)

## ui_cancel / Android back while open.
func back() -> void:
	if confirm_popup.visible:
		confirm_popup.hide()
		return
	if _current != "pause" and _from_pause:
		_show("pause")
		_from_pause = false
		return
	BookUI.close()

## New-word toast: open the Dictionary on that word, clearing filters that hide it.
func open_dictionary_entry(word_id: String) -> void:
	open("dictionary")
	if not _dict_list.focus_word(word_id):
		_dict_filter.clear_filters()
		_dict_list.focus_word(word_id)
	_panels["dictionary"].update_arrows()

func _show(id: String) -> void:
	AudioManager.play_sfx("menu_click")
	confirm_popup.hide()
	_current = id
	# "menus_ui" tutorial steps wait for these ("menus_map", "menus_pause", ...).
	TutorialManager.notify("menus_" + id)
	_pause.visible = id == "pause"
	for pid in _panels:
		_panels[pid].visible = pid == id
	if id == "pause":
		_refresh_pause()
	else:
		_panels[id].show_panel()
		if id == "settings":
			# Only this panel's copy of the page: the book keeps its own look.
			for btn in _settings_page.ui_scale_row.get_children():
				MenuStyle.style_chip(btn)
			for slider in _settings_page.find_children("*", "HSlider", true, false):
				MenuStyle.style_slider(slider)
			for toggle in _settings_page.find_children("*", "CheckButton", true, false):
				MenuStyle.style_toggle(toggle)

func _open_from_pause(id: String) -> void:
	_show(id)
	_from_pause = true

# --- Pause menu ---------------------------------------------------------------

func _build_pause() -> void:
	_pause = CenterContainer.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pause)
	var box := PanelContainer.new()
	box.custom_minimum_size.x = PAUSE_WIDTH
	box.add_theme_stylebox_override("panel", MenuStyle.tile_style(MenuStyle.TILE_WHOLE, 10))
	_pause.add_child(box)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var title := MenuStyle.label("Paused", UIThemeApplier.FONT_SIZE_XXL, UIThemeApplier.TEXT_EMPHASIS)
	UIThemeApplier.apply_display_font(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_build_tier_card())

	var continue_btn := MenuStyle.text_button("Continue", MenuStyle.ICON_CONTINUE)
	continue_btn.pressed.connect(BookUI.close)
	TutorialManager.register_target("pause_continue", continue_btn)
	vbox.add_child(continue_btn)
	var achievements_btn := MenuStyle.text_button("Achievements", MenuStyle.ICON_ACHIEVEMENTS)
	achievements_btn.pressed.connect(_open_from_pause.bind("achievements"))
	vbox.add_child(achievements_btn)
	var settings_btn := MenuStyle.text_button("Settings", MenuStyle.ICON_SETTINGS)
	settings_btn.pressed.connect(_open_from_pause.bind("settings"))
	vbox.add_child(settings_btn)
	_dev_btn = MenuStyle.text_button("Dev menu", MenuStyle.ICON_DEV)
	_dev_btn.pressed.connect(_open_from_pause.bind("dev"))
	vbox.add_child(_dev_btn)
	var exit_btn := MenuStyle.text_button("Exit to menu", MenuStyle.ICON_EXIT, "danger")
	exit_btn.pressed.connect(BookUI.confirm_exit_to_menu)
	vbox.add_child(exit_btn)

## Read-only learning tier: "Tier 2 ... 38/60", bar, "22 more to Tier 3".
func _build_tier_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MenuStyle.card_style(6))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)
	var top := HBoxContainer.new()
	vbox.add_child(top)
	_tier_label = MenuStyle.label("", UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS)
	_tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tier_label)
	_tier_count = MenuStyle.label("", UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DISABLED)
	top.add_child(_tier_count)
	_tier_bar = MenuStyle.tier_bar()
	vbox.add_child(_tier_bar)
	_tier_hint = MenuStyle.label("", UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DISABLED)
	vbox.add_child(_tier_hint)
	return card

func _refresh_pause() -> void:
	_dev_btn.visible = GameState.dev_mode
	var tier: int = GameState.get_difficulty_tier()
	var total: int = GameState.get_total_mastery()
	var thresholds: Array = GameState.DIFFICULTY_TIER_MASTERY
	_tier_label.text = "Tier %d" % tier
	_tier_bar.value = GameState.get_tier_progress()
	if tier > thresholds.size():
		_tier_count.text = str(total)
		_tier_hint.text = "Max tier"
	else:
		var goal: int = thresholds[tier - 1]
		_tier_count.text = "%d / %d" % [total, goal]
		_tier_hint.text = "%d more to Tier %d" % [goal - total, tier + 1]

# --- Panels -------------------------------------------------------------------

func _build_panels() -> void:
	_add_panel("quests", QuestsPanel.new())
	_add_panel("achievements", AchievementsPanel.new())

	var settings := MenuPanel.new("Settings")
	_settings_page = PageSettingsScene.instantiate()
	settings.add_page(_settings_page)
	_add_panel("settings", settings)

	var dictionary := MenuPanel.new("Dictionary", true)
	_dict_filter = PageDictionaryFilterScene.instantiate()
	_dict_list = PageDictionaryListScene.instantiate()
	dictionary.add_spread(_dict_filter, _dict_list)
	_dict_filter.filters_changed.connect(_dict_list.apply_filter)
	_dict_filter.filters_changed.connect(func(_q, _c): dictionary.update_arrows())
	_add_panel("dictionary", dictionary)

	var map := MenuPanel.new("Map")
	map.add_page(PageMapScene.instantiate(), MAP_SIZE)
	_add_panel("map", map)

	# One piece: month grid (arrows beside the month name) on top, that
	# month's events scrolling underneath.
	var calendar := MenuPanel.new("Calendar")
	var cal_grid := Control.new()
	cal_grid.set_script(PageCalendarScript)
	var cal_events := Control.new()
	cal_events.set_script(PageCalendarEventsScript)
	calendar.add_page(cal_grid, CALENDAR_GRID_SIZE)
	# Grid keeps its own height; the events list takes the rest.
	calendar.content.get_child(0).size_flags_vertical = Control.SIZE_FILL
	calendar.add_page(cal_events)
	# String names: both are plain Controls to the analyzer until set_script.
	cal_grid.connect("month_changed", Callable(cal_events, "show_month"))
	cal_grid.connect("day_selected", Callable(cal_events, "show_day"))
	_add_panel("calendar", calendar)
	# The pages set their anchors in _ready() but keep offsets that cancel them
	# out here (their holders already have a size); zero the offsets.
	for page: Control in [cal_grid, cal_events]:
		page.set_offsets_preset(Control.PRESET_FULL_RECT)
	cal_grid.call("add_month_arrows",
			MenuStyle.icon_button(MenuStyle.ICON_PREV, Vector2(20, 20)),
			MenuStyle.icon_button(MenuStyle.ICON_NEXT, Vector2(20, 20)))

	_add_panel("dev", DevPanel.new())

func _add_panel(id: String, panel: Control) -> void:
	panel.back_pressed.connect(back)
	add_child(panel)
	_panels[id] = panel
