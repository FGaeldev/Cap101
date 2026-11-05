# instructions_panel.gd -- Instructions screen: how to play, plus what each
# chapter is about. Opens from the main menu and from the Book's Settings tab.
# Built in code and added to the root, so it can sit over a paused Book.
extends CanvasLayer

## Above BookUI (100) and ChapterCard (102).
const PANEL_LAYER: int = 103
const DIM := Color(0.0, 0.0, 0.0, 0.6)
const MARGIN: float = 0.05

const HOW_TO_PLAY: Array = [
	["Moving", "Drag the joystick at the bottom left, or use W, A, S, D."],
	["Talking and using things", "Walk up to a person or object, then tap the button at the bottom right or press E. Tap the screen or press E to continue a conversation."],
	["Your goal", "Your current quest is shown at the top left. Follow it to move the story forward."],
	["The Book", "Tap the menu button at the top right or press Esc. It holds your settings, journal, relationships, dictionary, map, and calendar."],
	["Learning Akeanon", "Akeanon words have their own color in conversations. Every word you find is saved in the Dictionary. Choose Review when you talk to someone to practice words. Practice fills the word tier bar at the top of the screen."],
	["Days", "Read the newspaper for the word of the day and a daily puzzle. Sleep in a bed to start a new day."],
	["Getting help", "Quizzes, minigames, and other activities have a ? button. Tap it to see how that activity works. You can also read them all under Activities on this screen."],
	["Stopping and continuing", "The game saves as you play. To stop, open the Book, go to Settings, and choose Return to Menu. To keep playing later, choose Continue on the main menu."],
]
## One page per activity. Hardcoded on purpose (Android PCK, see TutorialManager).
const HELP_DATA_PATH: String = "res://data/help_topics.json"

var _how_to_play_page: Control
var _chapters_page: Control
var _activities_page: Control
## Set by open_topic(): show only this activity's page, with no tabs.
var _topic: String = ""


## Opens the screen on top of everything. Closing it frees it.
static func open(tree: SceneTree) -> void:
	var panel := new()
	tree.root.add_child(panel)


## Opens one activity's page (the "?" buttons, see help_button.gd).
static func open_topic(tree: SceneTree, topic: String) -> void:
	var panel := new()
	panel._topic = topic
	tree.root.add_child(panel)


static func _load_topics() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(HELP_DATA_PATH))
	if parsed is Dictionary:
		return parsed
	push_error("instructions_panel: bad JSON in %s" % HELP_DATA_PATH)
	return {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = PANEL_LAYER
	if _topic.is_empty():
		_build_ui()
		_show_page(_how_to_play_page)
	else:
		_build_topic_ui()


## Esc closes this screen only, not the Book or the game behind it. Other keys
## stop here too, so typing can't reach a crossword or hangman behind the page.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	AudioManager.play_sfx("menu_click")
	queue_free()


func _show_page(page: Control) -> void:
	_how_to_play_page.visible = page == _how_to_play_page
	_chapters_page.visible = page == _chapters_page
	_activities_page.visible = page == _activities_page


func _build_topic_ui() -> void:
	var topic: Dictionary = _load_topics().get(_topic, {})
	if topic.is_empty():
		push_error("instructions_panel: no help topic '%s'" % _topic)
	var column := _build_frame()
	var header := _build_header(column, str(topic.get("title", "Help")))
	header.add_child(_make_button("Close", _close))
	var page := _make_page(column)
	_fill_topic(page.get_child(0), topic)


func _build_ui() -> void:
	var column := _build_frame()
	var header := _build_header(column, "Instructions")

	_how_to_play_page = _make_page(column)
	_chapters_page = _make_page(column)
	_activities_page = _make_page(column)
	_fill_how_to_play(_how_to_play_page.get_child(0))
	_fill_chapters(_chapters_page.get_child(0))
	_fill_activities(_activities_page.get_child(0))

	header.add_child(_make_button("How to Play", func(): _show_page(_how_to_play_page)))
	header.add_child(_make_button("Chapters", func(): _show_page(_chapters_page)))
	header.add_child(_make_button("Activities", func(): _show_page(_activities_page)))
	header.add_child(_make_button("Close", _close))


## Dim background and parchment panel. Returns the column content goes in.
func _build_frame() -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = MARGIN
	panel.anchor_top = MARGIN
	panel.anchor_right = 1.0 - MARGIN
	panel.anchor_bottom = 1.0 - MARGIN
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(18))
	dim.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	return column


## Title row. Returns the row, for its buttons.
func _build_header(column: Control, title_text: String) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)

	var title := _make_label(title_text, UIThemeApplier.FONT_SIZE_XXL, UIThemeApplier.TEXT_EMPHASIS, false)
	UIThemeApplier.apply_display_font(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	return header


func _make_page(parent: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 2)
	scroll.add_child(content)
	return scroll


func _fill_how_to_play(content: Control) -> void:
	for section: Array in HOW_TO_PLAY:
		_add_section(content, section[0], [section[1]])


func _fill_chapters(content: Control) -> void:
	for chapter: Dictionary in ChapterCard.get_chapters():
		var heading: String = "Chapter %d: %s" % [int(chapter.get("number", 0)), str(chapter.get("title", ""))]
		if not chapter.get("available", false):
			heading += " (coming soon)"
		_add_section(content, heading, [str(chapter.get("description", "")), "You will learn: %s" % str(chapter.get("learn", ""))])


## One button per activity, opening the same page as that activity's "?" button.
func _fill_activities(content: Control) -> void:
	content.add_theme_constant_override("separation", 4)
	var topics: Dictionary = _load_topics()
	for topic_id: String in topics:
		var tree := get_tree()
		content.add_child(_make_button(str(topics[topic_id].get("title", topic_id)), func(): open_topic(tree, topic_id)))


func _fill_topic(content: Control, topic: Dictionary) -> void:
	_add_section(content, "Goal", [str(topic.get("goal", ""))])
	var steps: Array = []
	for step: String in topic.get("steps", []):
		steps.append("%d. %s" % [steps.size() + 1, step])
	_add_section(content, "How to play", steps)
	var tips: Array = topic.get("tips", [])
	if not tips.is_empty():
		_add_section(content, "Good to know", tips)


func _add_section(content: Control, heading: String, lines: Array) -> void:
	var heading_label := _make_label(heading, UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS, true)
	content.add_child(heading_label)
	for line: String in lines:
		content.add_child(_make_label(line, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT, true))


func _make_label(text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 26)
	button.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	UIThemeApplier.apply_button_theme(button, "primary")
	button.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		on_pressed.call()
	)
	return button
