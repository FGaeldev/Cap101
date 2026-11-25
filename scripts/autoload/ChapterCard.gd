# ChapterCard.gd -- chapter-start and new-area banners (banner_card.gd), and the
# full-screen card for one-off notes (the end of Part One).
#
# Chapter text lives in CHAPTER_DATA_PATH, which the Instructions screen also
# reads. Each card shows once per save ("chapter_card_<id>_seen"), and never in
# dev mode so dev warps stay quick.
#
# Usage:
#   await ChapterCard.show_if_new("chapter2")
#   or the cutscene step {"type": "chapter_card", "chapter": "chapter2"}
extends CanvasLayer

signal closed

## Hardcoded on purpose (Android PCK, same as TutorialManager).
const CHAPTER_DATA_PATH: String = "res://data/chapters.json"
## Above ScreenFade (100): chapters often begin on a black screen.
const CARD_LAYER: int = 102
const BACKGROUND := Color("0a1a0e")  # same as the main menu
const PANEL_WIDTH: float = 440.0
## Stops a key press meant for the previous screen from skipping the card, and
## lets a warp's fade-in finish before the card can close.
const MIN_SHOW_SECONDS: float = 0.8
const AREA_DATA_PATH: String = "res://data/map_data/area_banners.json"
const BannerCard := preload("res://scripts/ui/banner_card.gd")

## Chapter-start and new-area banner, its own CanvasLayer on the root.
var _banner: CanvasLayer
var _areas: Dictionary = {}

var _chapters: Array = []
var _chapter_label: Label
var _title_label: Label
var _description_label: Label
var _learn_label: Label
var _continue_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CARD_LAYER
	_load_data()
	_build_ui()
	hide()
	_banner = BannerCard.new()
	_banner.name = "BannerCard"
	get_tree().root.add_child.call_deferred(_banner)
	set_process_input(false)


## Every chapter in story order, for the Instructions screen.
func get_chapters() -> Array:
	return _chapters


## A chapter start: the "Chapter N / title / Started" banner (banner_card.gd),
## once per save. It plays over the game and fades by itself, so this never
## waits and never leaves the screen black: it returns false either way, so a
## caller's "fade_in_after" doesn't fade a screen that is already showing.
func show_if_new(chapter_id: String) -> bool:
	var flag: String = "chapter_card_%s_seen" % chapter_id
	var chapter: Dictionary = _find_chapter(chapter_id)
	if GameState.skips_cards() or GameState.get_flag(flag):
		return false
	if chapter.is_empty():
		push_warning("ChapterCard: unknown chapter '%s'" % chapter_id)
		return false
	GameState.set_flag(flag)
	_show_chapter_banner(chapter)
	return false


## Any short notice on the same banner card (lessons.gd: "Lesson missed").
func show_notice(header: String, title: String, pill: String) -> void:
	_banner.show_banner(header, title, pill)


func _show_chapter_banner(chapter: Dictionary) -> void:
	_banner.show_banner("Chapter %d" % int(chapter.get("number", 0)), str(chapter.get("title", "")), "Started")


## First visit to a place (data/map_data/area_banners.json, keyed by level
## scene path): its name on the same banner with "Discovered". Once per place
## per save; maps of one place share its "key". Game.load_level() calls this.
func show_area_if_new(scene_path: String) -> void:
	if _areas.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AREA_DATA_PATH))
		_areas = parsed if parsed is Dictionary else {"_bad": {}}
	var area: Dictionary = _areas.get(scene_path, {})
	if area.is_empty() or GameState.skips_cards():
		return
	var flag: String = "area_banner_%s_seen" % str(area.get("key", scene_path.get_file().get_basename()))
	if GameState.get_flag(flag):
		return
	GameState.set_flag(flag)
	_banner.show_banner(str(area.get("header", "")), str(area.get("title", "")), "Discovered")


## One-off notes on the same card, shown once per save ("note_<id>_seen").
## story_so_far: after the last finished chapter, so players don't wait for a
## quest that isn't built yet (v0.1.19 playtest). When the next chapter ships,
## point "after_flag" at the new last chapter, update the text, give it a new
## "seen_flag" (so saves that saw the old note see this one), and move the
## chapter_card step to that chapter's last cutscene.
const NOTES: Dictionary = {
	"story_so_far": {
		"after_flag": "chapter4_complete",
		"seen_flag": "note_part_one_end_seen",
		"heading": "The end of Part One",
		"title": "Salamat, and well done!",
		"body": "You came home to Aklan, toured Kalibo with Rose, wove piña with Manang Loleng, and planted a mangrove with Manong Ambo.",
		"footer": "Kalibo is still yours to explore: talk to people, run errands for the family, and keep practicing your words.",
	},
}

## Shows a NOTES entry once per save, if its after_flag is set. Same rules as
## the chapter cards (skipped in dev mode unless the Dev switch is on). Returns true if it showed; closing
## leaves the screen black, so the caller fades back in.
func show_note_if_new(note_id: String) -> bool:
	var note: Dictionary = NOTES.get(note_id, {})
	var flag: String = str(note.get("seen_flag", "note_%s_seen" % note_id))
	if note.is_empty() or GameState.skips_cards() or GameState.get_flag(flag) or visible:
		return false
	if not GameState.get_flag(str(note.get("after_flag", ""))):
		return false
	GameState.set_flag(flag)
	_chapter_label.text = str(note.get("heading", ""))
	_title_label.text = str(note.get("title", ""))
	_description_label.text = str(note.get("body", ""))
	_learn_label.text = str(note.get("footer", ""))
	_continue_btn.disabled = true
	show()
	set_process_input(true)
	get_tree().create_timer(MIN_SHOW_SECONDS).timeout.connect(func(): _continue_btn.disabled = false)
	await closed
	GameState.save_game()
	return true

## A save loaded after its story ran out (it finished Chapter 3 before this note
## existed): show the note once the level is up, then fade back in.
func show_note_on_load(note_id: String) -> void:
	if CutsceneManager.is_playing() or MapManager.is_transitioning:
		return
	if await show_note_if_new(note_id):
		await FadeManager.fade_in(0.6)


func _find_chapter(chapter_id: String) -> Dictionary:
	for chapter: Dictionary in _chapters:
		if chapter.get("id", "") == chapter_id:
			return chapter
	return {}


## Keys never reach the game behind the card (Esc would open the Book).
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_on_continue()


func _on_continue() -> void:
	if _continue_btn.disabled:
		return
	_continue_btn.disabled = true
	set_process_input(false)
	AudioManager.play_sfx("menu_click")
	# Black first, so removing the card never flashes the room behind it before
	# the level's own fade-in.
	await FadeManager.fade_out(0.0)
	hide()
	closed.emit()


func _load_data() -> void:
	var file: FileAccess = FileAccess.open(CHAPTER_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("ChapterCard: cannot open %s" % CHAPTER_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		_chapters = parsed
	else:
		push_error("ChapterCard: bad JSON in %s" % CHAPTER_DATA_PATH)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(18))
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	_chapter_label = _add_label(column, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED)
	_title_label = _add_label(column, UIThemeApplier.FONT_SIZE_XXL, UIThemeApplier.TEXT_EMPHASIS)
	UIThemeApplier.apply_display_font(_title_label)
	_description_label = _add_label(column, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT)
	_learn_label = _add_label(column, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(120, 26)
	_continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIThemeApplier.apply_button_theme(_continue_btn, "primary")
	_continue_btn.pressed.connect(_on_continue)
	column.add_child(_continue_btn)


func _add_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## Dev menu replay: shows a chapter card or a note right now, even if this save
## has seen it or dev mode is on, then fades back in. Changes no flags.
func replay(id: String) -> void:
	if visible:
		return
	var chapter: Dictionary = _find_chapter(id)
	var note: Dictionary = NOTES.get(id, {})
	if not chapter.is_empty():
		_show_chapter_banner(chapter)
		return
	elif not note.is_empty():
		_chapter_label.text = str(note.get("heading", ""))
		_title_label.text = str(note.get("title", ""))
		_description_label.text = str(note.get("body", ""))
		_learn_label.text = str(note.get("footer", ""))
	else:
		push_warning("ChapterCard: nothing to replay for '%s'" % id)
		return
	_continue_btn.disabled = true
	show()
	set_process_input(true)
	get_tree().create_timer(MIN_SHOW_SECONDS).timeout.connect(func(): _continue_btn.disabled = false)
	await closed
	await FadeManager.fade_in(0.6)
