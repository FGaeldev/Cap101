# BookUI.gd — autoload. Single entry point for relationship/dictionary/journal/settings/map.
extends CanvasLayer

@export var page_left_path: NodePath = ^"Root/Spread/PageLeft"
@onready var page_left: Panel = get_node(page_left_path)
@export var page_right_path: NodePath = ^"Root/Spread/PageRight"
@onready var page_right: Panel = get_node(page_right_path)
@export var spread_path: NodePath = ^"Root/Spread"
@onready var spread: Control = get_node(spread_path)
@export var page_map_host_path: NodePath = ^"Root/PageMapHost"
@onready var page_map_host: Control = get_node(page_map_host_path)
@export var confirm_popup_path: NodePath = ^"Root/ConfirmPopup"
@onready var confirm_popup: ConfirmPopup = get_node(confirm_popup_path)

# -- Page Scenes --
const PageSettingsScene := preload("res://scenes/ui/page_settings.tscn")
const PageDictionaryListScene := preload("res://scenes/ui/page_dictionary.tscn")
const PageDictionaryFilterScene := preload("res://scenes/ui/page_dictionary_filter.tscn")
const PageRelationshipScene := preload("res://scenes/ui/page_relationship.tscn")
const PageJournalScene := preload("res://scenes/ui/page_journal.tscn")
const PageJournalAchievementsScene := preload("res://scenes/ui/page_journal_achievements.tscn")
const PageMapScene := preload("res://scenes/ui/page_map.tscn")

const MARKER := preload("res://assets/ui/book/marker.png")
const MARKER_SLICE_MARGIN := 3

## Tutorial id (data/tutorials/tutorials.json) that only makes sense while the Book is open.
const BOOK_TUTORIAL_ID := "book_ui"

const TAB_HOVER_SCALE := 1.15
const TAB_ANIM_TIME := 0.12

# tab_id -> { button: Button, title: String, is_unlocked: Callable,
#             page: Control, page_right: Control (optional),
#             full_spread: bool (optional) }
var _tabs: Dictionary = {}
var _current_tab: String = ""

@export var root_path: NodePath = ^"Root"
@onready var root: Control = get_node(root_path)
@export var title_label_path: NodePath = ^"Root/Banner/Title"
@onready var title_label: Label = get_node(title_label_path)
@export var close_btn_path: NodePath = ^"Root/CloseButton"
@onready var close_btn: Button = get_node(close_btn_path)
@export var bottom_bar_path: NodePath = ^"Root/BottomBar"
@onready var bottom_bar: HBoxContainer = get_node(bottom_bar_path)
@export var arrow_left_path: NodePath = ^"Root/BottomBar/ArrowLeft"
@onready var arrow_left: Button = get_node(arrow_left_path)
@export var arrow_right_path: NodePath = ^"Root/BottomBar/ArrowRight"
@onready var arrow_right: Button = get_node(arrow_right_path)

## Horizontal inset (px) between a page edge and its arrow buttons.
const ARROW_PAGE_INSET := 6
## Fraction of page width the OUTER-edge arrow is pulled inward (left page:
## left arrow moves right; right page: right arrow moves left).
const ARROW_OUTER_SHIFT := 0.10
## Must match ArrowLeft/ArrowRight custom_minimum_size.x in book_ui.tscn.
const ARROW_WIDTH := 16

## Per-side arrow bars. "page" = PageLeft's bar (the scene's BottomBar),
## "page_right" = PageRight's bar (runtime duplicate of BottomBar, built in
## _ready). Each side paginates independently of the other.
var _bars: Dictionary = {}    # side key -> HBoxContainer
var _arrows: Dictionary = {}  # side key -> {"prev": Button, "next": Button}
@export var tab_settings_path: NodePath = ^"Root/TabBar/TabSettings"
@onready var tab_settings: Button = get_node(tab_settings_path)
@export var tab_quest_path: NodePath = ^"Root/TabBar/TabBucketList"
@onready var tab_quest: Button = get_node(tab_quest_path)
@export var tab_rapport_path: NodePath = ^"Root/TabBar/TabRelationship"
@onready var tab_rapport: Button = get_node(tab_rapport_path)
@export var tab_dictionary_path: NodePath = ^"Root/TabBar/TabDictionary"
@onready var tab_dictionary: Button = get_node(tab_dictionary_path)
@export var tab_map_path: NodePath = ^"Root/TabBar/TabMap"
@onready var tab_map: Button = get_node(tab_map_path)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_btn.pressed.connect(close)
	# Duplicate BEFORE connecting signals so the copy doesn't inherit
	# left-page connections.
	var bar_right: HBoxContainer = bottom_bar.duplicate() as HBoxContainer
	bar_right.name = "BottomBarRight"
	bottom_bar.get_parent().add_child(bar_right)
	_bars = {"page": bottom_bar, "page_right": bar_right}
	_arrows = {
		"page": {"prev": arrow_left, "next": arrow_right},
		"page_right": {
			"prev": bar_right.get_node("ArrowLeft"),
			"next": bar_right.get_node("ArrowRight"),
		},
	}
	for side in _arrows:
		_arrows[side]["prev"].pressed.connect(_on_arrow_pressed.bind(side, false))
		_arrows[side]["next"].pressed.connect(_on_arrow_pressed.bind(side, true))
		_arrows[side]["prev"].add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
		_arrows[side]["next"].add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_register_tab("relationship", tab_rapport, "RELATIONSHIP")
	var rel_left := PageRelationshipScene.instantiate()
	var rel_right := PageRelationshipScene.instantiate()
	page_left.add_child(rel_left)
	page_right.add_child(rel_right)
	rel_left.visible = false
	rel_right.visible = false
	rel_left.partner_column = rel_right  # left owns pagination for both halves
	_tabs["relationship"]["page"] = rel_left
	_tabs["relationship"]["page_right"] = rel_right
	_register_tab("bucket_list", tab_quest, "JOURNAL")
	var journal_quests := PageJournalScene.instantiate()
	var journal_achievements := PageJournalAchievementsScene.instantiate()
	page_left.add_child(journal_quests)
	page_right.add_child(journal_achievements)
	journal_quests.visible = false
	journal_achievements.visible = false
	_tabs["bucket_list"]["page"] = journal_quests             # PageLeft — paginated
	_tabs["bucket_list"]["page_right"] = journal_achievements  # PageRight — fits one page at current scale
	
	# -- assigning page to tabs
	_register_tab("settings", tab_settings, "SETTINGS")
	_tabs["settings"]["page"] = PageSettingsScene.instantiate()
	page_left.add_child(_tabs["settings"]["page"])
	_tabs["settings"]["page"].visible = false
	
	_register_tab("dictionary", tab_dictionary, "DICTIONARY")
	var dict_filter := PageDictionaryFilterScene.instantiate()
	var dict_list := PageDictionaryListScene.instantiate()
	page_left.add_child(dict_filter)
	page_right.add_child(dict_list)
	dict_filter.visible = false
	dict_list.visible = false
	dict_filter.filters_changed.connect(dict_list.apply_filter)
	_tabs["dictionary"]["page"] = dict_filter        # PageLeft
	_tabs["dictionary"]["page_right"] = dict_list    # PageRight
	set_tab_lock_condition("dictionary", func(): return not GameState.word_exposures.is_empty())

	# Map — spans the whole spread (both pages) instead of living in
	# PageLeft/PageRight, so it gets a PNG map bg uninterrupted by the
	# page-seam. Registered under "page" like every other tab so the
	# existing _show_page/_hide_page plumbing needs no special case; the
	# only extra bit is hiding the parchment Spread panels underneath
	# (see switch_tab). page_map_host is the anchor-matched sibling of
	# Spread that hosts it — see book_ui.tscn.
	_register_tab("map", tab_map, "MAP")
	var map_page := PageMapScene.instantiate()
	page_map_host.add_child(map_page)
	map_page.visible = false
	page_map_host.visible = false  # host itself must be hidden too, not just its child — else it still eats mouse input over the pages rect while on other tabs
	_tabs["map"]["page"] = map_page
	_tabs["map"]["full_spread"] = true

	TutorialManager.register_target("book_settings", tab_settings)
	TutorialManager.register_target("book_quest", tab_quest)
	TutorialManager.register_target("book_rapport", tab_rapport)
	TutorialManager.register_target("book_dictionary", tab_dictionary)
	TutorialManager.register_target("book_map", tab_map)
	TutorialManager.register_target("book_close", close_btn)
	
	

func _make_marker_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = MARKER
	sb.texture_margin_left = MARKER_SLICE_MARGIN
	sb.texture_margin_top = MARKER_SLICE_MARGIN
	sb.texture_margin_right = MARKER_SLICE_MARGIN
	sb.texture_margin_bottom = MARKER_SLICE_MARGIN
	# inset the icon so it doesn't touch/clip the marker's edge art
	sb.content_margin_left = 3
	sb.content_margin_top = 3
	sb.content_margin_right = 3
	sb.content_margin_bottom = 3
	return sb

func _register_tab(tab_id: String, button: Button, title: String) -> void:
	_tabs[tab_id] = {"button": button, "title": title, "is_unlocked": func(): return true}
	var style := _make_marker_style()
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	call_deferred("_set_pivot_bottom_left", button)
	button.mouse_entered.connect(func(): _animate_tab(tab_id, TAB_HOVER_SCALE))
	button.mouse_exited.connect(func(): _animate_tab(tab_id, TAB_HOVER_SCALE if tab_id == _current_tab else 1.0))
	button.pressed.connect(func(): switch_tab(tab_id))

func _set_pivot_bottom_left(button: Button) -> void:
	button.pivot_offset = Vector2(0, button.size.y)

func _animate_tab(tab_id: String, target_scale: float) -> void:
	_animate_button(_tabs[tab_id]["button"], target_scale)

func _animate_button(button: Button, target_scale: float) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), TAB_ANIM_TIME)

## Exit-to-menu trigger moved back to Settings page (page_settings.gd Quit
## button) — this is just the shared confirm+abort sequence now, called from
## there instead of from a tab-bar button.
func confirm_exit_to_menu() -> void:
	confirm_popup.open("Return to menu?")
	if not confirm_popup.confirmed.is_connected(_on_return_confirmed):
		confirm_popup.confirmed.connect(_on_return_confirmed)
	
	
func _on_return_confirmed() -> void:
	AudioManager.play_sfx("menu_click")
	CutsceneManager.abort()
	TutorialManager.abort()
	GameState.save_game()
	close()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

## "Exit to main menu" makes no sense from MainMenu itself -- no active
## session, and confirm_exit_to_menu()'s save_game() call would silently
## overwrite an existing save with whatever stale/default data currently
## sits in the GameState singleton. page_settings.gd's Quit button uses this
## to hide itself in that context (same guard this used to apply to itself).
func is_main_menu_context() -> bool:
	return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == "res://scenes/ui/MainMenu.tscn"

## Callable must return bool. Used to lock e.g. Dictionary before first word exposed.
func set_tab_lock_condition(tab_id: String, is_unlocked: Callable) -> void:
	if _tabs.has(tab_id):
		_tabs[tab_id]["is_unlocked"] = is_unlocked

func open(tab_id: String = "settings") -> void:
	visible = true
	get_tree().paused = true
	switch_tab(tab_id)

func close() -> void:
	AudioManager.play_sfx("menu_click")
	visible = false
	get_tree().paused = false
	# Last step of the "book_ui" tutorial waits for the player to close the Book.
	TutorialManager.notify("book_tutorial_finished")
	# Closed early = tutorial has no open Book left to act on. Drop it (NOT
	# marked done) so the bedroom book restarts it from the top next time.
	if TutorialManager.active_id() == BOOK_TUTORIAL_ID:
		TutorialManager.abort()

func switch_tab(tab_id: String) -> void:
	if not _tabs.has(tab_id):
		push_error("BookUI: unknown tab '%s'" % tab_id)
		return
	var entry: Dictionary = _tabs[tab_id]
	if not entry["is_unlocked"].call():
		return
	AudioManager.play_sfx("menu_click")
	if not _current_tab.is_empty() and _current_tab != tab_id:
		_animate_tab(_current_tab, 1.0)
		_hide_page(_tabs[_current_tab], "page")
		_hide_page(_tabs[_current_tab], "page_right")
	_current_tab = tab_id
	match tab_id:
		"settings":
			TutorialManager.notify("book_settings")
		"bucket_list":
			TutorialManager.notify("book_quest")
		"relationship":
			TutorialManager.notify("book_rapport")
		"dictionary":
			TutorialManager.notify("book_dictionary")
		"map":
			TutorialManager.notify("book_map")
	_animate_tab(tab_id, TAB_HOVER_SCALE)
	title_label.text = entry["title"]
	# Map draws over both pages with a transparent-bg PNG, so parchment
	# stays visible underneath instead of being hidden. page_map_host still
	# toggles — it hosts the map's clickable marker layer.
	var is_full_spread: bool = entry.get("full_spread", false)
	page_map_host.visible = is_full_spread
	_show_page(entry, "page")
	_show_page(entry, "page_right")
	_update_bottom_bar()

## Returns the page node on `side` ("page" or "page_right") of tab_id if it
## paginates (exposes next_page()/prev_page()/has_next_page()/has_prev_page()),
## else null. Each side is checked independently, so a tab may paginate on
## the left, the right, both, or neither.
func _get_paginated_page(tab_id: String, side: String):
	var page = _tabs.get(tab_id, {}).get(side)
	if page != null and page.has_method("next_page"):
		return page
	return null

## Per side: shows that side's arrow bar only if its page paginates AND has
## somewhere to go (a prev or next page), snaps the bar under its own page,
## and syncs prev/next enabled state. Single-page content hides the bar.
func _update_bottom_bar() -> void:
	for side in _bars:
		var bar: HBoxContainer = _bars[side]
		var page = _get_paginated_page(_current_tab, side)
		var has_pages: bool = page != null and (page.has_prev_page() or page.has_next_page())
		bar.visible = has_pages
		if not has_pages:
			continue
		var host: Control = page_left if side == "page" else page_right
		var shift: float = host.size.x * ARROW_OUTER_SHIFT
		var is_left: bool = side == "page"
		var width: float = host.size.x - ARROW_PAGE_INSET * 2 - shift
		# Separation MUST be set before size: the scene's baked-in separation
		# (428) sets the HBox minimum width and would clamp size.x otherwise.
		bar.add_theme_constant_override(
			"separation", maxi(0, int(width) - ARROW_WIDTH * 2))
		bar.size = Vector2(width, bar.size.y)
		# Left page: bar starts further right (left arrow shifts in).
		# Right page: bar starts at normal inset, ends sooner (right arrow shifts in).
		var x_offset: float = ARROW_PAGE_INSET + (shift if is_left else 0.0)
		bar.global_position.x = host.global_position.x + x_offset
		_arrows[side]["prev"].disabled = not page.has_prev_page()
		_arrows[side]["next"].disabled = not page.has_next_page()

## Shared handler for all four arrows. `side` = "page"/"page_right",
## `forward` = true for next, false for prev.
func _on_arrow_pressed(side: String, forward: bool) -> void:
	var page = _get_paginated_page(_current_tab, side)
	if page == null:
		return
	AudioManager.play_sfx("menu_click")
	if forward:
		page.next_page()
	else:
		page.prev_page()
	_update_bottom_bar()

func _hide_page(entry: Dictionary, key: String) -> void:
	if entry.has(key):
		entry[key].visible = false

func _show_page(entry: Dictionary, key: String) -> void:
	if entry.has(key):
		if entry[key].has_method("refresh"):
			entry[key].refresh()
		entry[key].visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open("settings")
