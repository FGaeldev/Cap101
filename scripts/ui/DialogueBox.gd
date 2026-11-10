# DialogueBox.gd — typewriter effect, portrait slot ready
extends PanelContainer

@onready var speaker_label: Label = $VBoxContainer/SpeakerLabel
## RichTextLabel so Akeanon words can have their own color (TextUtil.resolve_rich).
@onready var text_label:    RichTextLabel = $VBoxContainer/TextLabel

# --- Typewriter ---
## Length without BBCode tags: the typewriter counts visible characters.
var _visible_length: int  = 0
var _shown_chars: int     = 0
var _typing: bool         = false
var _type_speed: float    = 0.03
var _type_timer: float    = 0.0

# --- Tappable words ---
const WordPopup := preload("res://scripts/ui/word_popup.gd")
const WORD_TUTORIAL_ID: String = "word_tap"
const WORD_BORDER_WIDTH: float = 1.0
const WORD_BORDER_PADDING: float = 2.0
var _popup: Control
## Current line as authored, for redrawing it with a word selected.
var _raw_text: String = ""
## Index of the selected word in its line, -1 if none.
var _active_word: int = -1
## Link hit by the tap being handled, "" if the tap landed anywhere else.
var _tapped_meta: String = ""
var _tap_pending: bool = false
var _tap_position: Vector2 = Vector2.ZERO
var _screen_pressed: bool = false

func _ready() -> void:
	DialogueUI.register_box(self)
	_apply_style()
	_popup = WordPopup.new()
	add_child(_popup)
	text_label.meta_clicked.connect(_on_meta_clicked)
	text_label.draw.connect(_draw_word_border)

func _apply_style() -> void:
	# DialogueRoot paints the background; keep this panel transparent.
	$".".add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	speaker_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	text_label.add_theme_color_override("default_color", UIThemeApplier.TEXT_DEFAULT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Hidden (not yet typed) chars must still be shaped, else wrapped height
	# grows while typing and the panel resizes mid-line.
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	text_label.meta_underlined = false

## Display source text with the existing typewriter.
func display(speaker: String, text: String) -> void:
	_close_word()
	_raw_text = text
	speaker_label.text = TextUtil.resolve_speaker(speaker)
	var plain_text: String = TextUtil.resolve(text)
	_visible_length = plain_text.length()
	_shown_chars = 0
	_type_timer = 0.0
	if plain_text.strip_edges().is_empty():
		# Never silently render an empty dialogue panel when authored data is
		# missing its text field. Log the bad line and keep UI visibly diagnosable.
		push_warning("DialogueBox.display received an empty dialogue line for speaker '%s'." % speaker)
		_typing = false
		text_label.visible_characters = -1
		text_label.text = "…"
	else:
		_typing = true
		# Full text set up front so label min height is final; reveal via
		# visible_characters. Setting text per-char made the panel grow mid-type.
		text_label.text = TextUtil.resolve_rich(text)
		text_label.visible_characters = 0
	if DialogueUI._root != null:
		DialogueUI._root.refresh_layout()

func _process(delta: float) -> void:
	if not _typing:
		return
	_type_timer += delta
	if _type_timer >= _type_speed:
		_type_timer = 0.0
		_shown_chars += 1
		text_label.visible_characters = _shown_chars
		if _shown_chars >= _visible_length:
			_finish_typing()

func _finish_typing() -> void:
	_typing = false
	text_label.visible_characters = -1
	if text_label.text.contains("[url="):
		TutorialManager.start(WORD_TUTORIAL_ID)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		_screen_tap(event)
		return
	if not event.is_action_pressed("interact"):
		return
	if _close_word():
		get_viewport().set_input_as_handled()
		return
	_dialogue_input()

func _dialogue_input() -> void:
	# Choice dialogue must be resolved through a choice button, never by tapping
	# unused space in the dialogue panel or pressing the generic interact action.
	var choice_box := get_parent().get_node_or_null("ChoiceBox") as Control
	if choice_box != null and choice_box.visible:
		get_viewport().set_input_as_handled()
		return

	if _typing:
		_finish_typing()
	else:
		DialogueUI.player_pressed_advance()
	get_viewport().set_input_as_handled()

## Taps act on release, because that's when a link reports being hit. One tap
## arrives as both a touch and a mouse event, in an order that differs by
## platform, and only the mouse event finds the link. So it's decided once,
## after both have arrived.
func _on_gui_input(event: InputEvent) -> void:
	var is_release = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	if is_release:
		_tap_position = get_global_transform_with_canvas() * event.position
		_queue_tap()

## A tap outside the text. It has to have started while this line was up, so
## letting go of the joystick after walking into a cutscene doesn't skip a line.
func _screen_tap(event: InputEvent) -> void:
	if event.pressed:
		_screen_pressed = true
	elif _screen_pressed:
		_screen_pressed = false
		_queue_tap()
	get_viewport().set_input_as_handled()

func _on_meta_clicked(meta: Variant) -> void:
	if _typing:
		return  # the tap just finishes the line
	_tapped_meta = str(meta)
	_queue_tap()

func _queue_tap() -> void:
	if _tap_pending:
		return
	_tap_pending = true
	_resolve_tap.call_deferred()

func _resolve_tap() -> void:
	_tap_pending = false
	var meta: String = _tapped_meta
	_tapped_meta = ""
	if not meta.is_empty():
		_toggle_word(meta)
	elif not _close_word():
		_dialogue_input()

## meta is "<index>:<word>", see TextUtil.resolve_rich().
func _toggle_word(meta: String) -> void:
	var parts: PackedStringArray = meta.split(":", true, 1)
	var index: int = int(parts[0])
	if index == _active_word:
		_close_word()
		return
	var word: Dictionary = WordBank.get_word(WordBank.find_id_by_form(parts[1]))
	if word.is_empty():
		return
	_set_active_word(index)
	_popup.show_word(word["akeanon"], WordBank.glosses_for_form(parts[1]), _tap_position)
	TutorialManager.notify("word_tapped")

## Closes the open word, if any. Returns whether there was one.
func _close_word() -> bool:
	if _active_word == -1:
		return false
	_set_active_word(-1)
	_popup.close()
	return true

func _set_active_word(index: int) -> void:
	_active_word = index
	text_label.text = TextUtil.resolve_rich(_raw_text, index)
	text_label.visible_characters = -1

## RichTextLabel has no border tag and doesn't report where a word landed, so
## this measures it: which wrapped line it's on, and the text before it there.
func _draw_word_border() -> void:
	if _active_word == -1:
		return
	var span: Vector2i = TextUtil.marked_word_span(_raw_text, _active_word)
	if span.x == -1:
		return
	var line: int = text_label.get_character_line(span.x)
	var line_start: int = span.x
	while line_start > 0 and text_label.get_character_line(line_start - 1) == line:
		line_start -= 1
	var shown: String = text_label.get_parsed_text()
	var font: Font = text_label.get_theme_font("normal_font")
	var font_size: int = text_label.get_theme_font_size("normal_font_size")
	var before: String = shown.substr(line_start, span.x - line_start)
	var x: float = font.get_string_size(before, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var width: float = font.get_string_size(shown.substr(span.x, span.y), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var box := Rect2(x - WORD_BORDER_PADDING, text_label.get_line_offset(line),
			width + WORD_BORDER_PADDING * 2.0, font.get_height(font_size))
	text_label.draw_rect(box, Accessibility.akeanon_color(), false, WORD_BORDER_WIDTH)
