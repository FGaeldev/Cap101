# BookUI.gd — autoload. Single entry point for relationship/dictionary/journal/settings/map.
extends CanvasLayer

@onready var page_left: Panel = $Root/Spread/PageLeft
@onready var page_right: Panel = $Root/Spread/PageRight
@onready var spread: Control = $Root/Spread
@onready var page_map_host: Control = $Root/PageMapHost

# -- Page Scenes --
const PageSettingsScene := preload("res://scenes/ui/page_settings.tscn")
const PageDictionaryListScene := preload("res://scenes/ui/page_dictionary.tscn")
const PageDictionaryFilterScene := preload("res://scenes/ui/page_dictionary_filter.tscn")
const PageRelationshipScene := preload("res://scenes/ui/page_relationship.tscn")
const PageJournalScene := preload("res://scenes/ui/page_journal.tscn")
const PageMapScene := preload("res://scenes/ui/page_map.tscn")

const MARKER := preload("res://assets/ui/book/marker.png")
const MARKER_SLICE_MARGIN := 3

const TAB_HOVER_SCALE := 1.15
const TAB_ANIM_TIME := 0.12

# tab_id -> { button: Button, title: String, is_unlocked: Callable,
#             page: Control, page_right: Control (optional),
#             full_spread: bool (optional) }
var _tabs: Dictionary = {}
var _current_tab: String = ""

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Banner/Title
@onready var close_btn: Button = $Root/CloseButton
@onready var bottom_bar: HBoxContainer = $Root/BottomBar
@onready var arrow_left: Button = $Root/BottomBar/ArrowLeft
@onready var arrow_right: Button = $Root/BottomBar/ArrowRight

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_btn.pressed.connect(close)
	arrow_left.pressed.connect(_on_arrow_left_pressed)
	arrow_right.pressed.connect(_on_arrow_right_pressed)
	arrow_left.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	arrow_right.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_register_tab("relationship", $Root/TabBar/TabRelationship, "RELATIONSHIP")
	var rel_left := PageRelationshipScene.instantiate()
	var rel_right := PageRelationshipScene.instantiate()
	page_left.add_child(rel_left)
	page_right.add_child(rel_right)
	rel_left.visible = false
	rel_right.visible = false
	rel_left.partner_column = rel_right  # left owns pagination for both halves
	_tabs["relationship"]["page"] = rel_left
	_tabs["relationship"]["page_right"] = rel_right
	_register_tab("bucket_list", $Root/TabBar/TabBucketList, "JOURNAL")
	_tabs["bucket_list"]["page"] = PageJournalScene.instantiate()
	page_left.add_child(_tabs["bucket_list"]["page"])
	_tabs["bucket_list"]["page"].visible = false
	
	# -- assigning page to tabs
	_register_tab("settings", $Root/TabBar/TabSettings, "SETTINGS")
	_tabs["settings"]["page"] = PageSettingsScene.instantiate()
	page_left.add_child(_tabs["settings"]["page"])
	_tabs["settings"]["page"].visible = false
	
	_register_tab("dictionary", $Root/TabBar/TabDictionary, "DICTIONARY")
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
	_register_tab("map", $Root/TabBar/TabMap, "MAP")
	var map_page := PageMapScene.instantiate()
	page_map_host.add_child(map_page)
	map_page.visible = false
	_tabs["map"]["page"] = map_page
	_tabs["map"]["full_spread"] = true

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
	var button: Button = _tabs[tab_id]["button"]
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), TAB_ANIM_TIME)

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
	_animate_tab(tab_id, TAB_HOVER_SCALE)
	title_label.text = entry["title"]
	# full_spread tabs (Map) draw over both pages, so hide the parchment
	# Spread panels underneath rather than layering the map on top of them.
	spread.visible = not entry.get("full_spread", false)
	_show_page(entry, "page")
	_show_page(entry, "page_right")
	_update_bottom_bar()

## Generic — shows/enables the bottom bar for ANY tab whose primary "page"
## exposes next_page()/prev_page()/has_next_page()/has_prev_page(), not just
## Relationship. Future paginated tabs (Dictionary at scale, Journal) get
## this for free by implementing the same four methods.
func _update_bottom_bar() -> void:
	var page = _tabs[_current_tab].get("page")
	var paginated: bool = page != null and page.has_method("next_page")
	bottom_bar.visible = paginated
	if not paginated:
		return
	arrow_left.disabled = not page.has_prev_page()
	arrow_right.disabled = not page.has_next_page()

func _on_arrow_left_pressed() -> void:
	var page = _tabs[_current_tab].get("page")
	if page and page.has_method("prev_page"):
		AudioManager.play_sfx("menu_click")
		page.prev_page()
		_update_bottom_bar()

func _on_arrow_right_pressed() -> void:
	var page = _tabs[_current_tab].get("page")
	if page and page.has_method("next_page"):
		AudioManager.play_sfx("menu_click")
		page.next_page()
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
