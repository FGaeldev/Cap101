# ChapterCard.gd -- full-screen card describing a chapter when it begins.
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
	set_process_input(false)


## Every chapter in story order, for the Instructions screen.
func get_chapters() -> Array:
	return _chapters


## Shows the card and waits for the player, unless this save has already seen it.
func show_if_new(chapter_id: String) -> void:
	var flag: String = "chapter_card_%s_seen" % chapter_id
	var chapter: Dictionary = _find_chapter(chapter_id)
	if GameState.dev_mode or GameState.get_flag(flag):
		return
	if chapter.is_empty():
		push_warning("ChapterCard: unknown chapter '%s'" % chapter_id)
		return
	GameState.set_flag(flag)
	_chapter_label.text = "Chapter %d" % int(chapter.get("number", 0))
	_title_label.text = str(chapter.get("title", ""))
	_description_label.text = str(chapter.get("description", ""))
	_learn_label.text = "You will learn: %s" % str(chapter.get("learn", ""))
	_continue_btn.disabled = true
	show()
	set_process_input(true)
	get_tree().create_timer(MIN_SHOW_SECONDS).timeout.connect(func(): _continue_btn.disabled = false)
	await closed


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
