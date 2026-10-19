# DialogueBox.gd — typewriter effect, portrait slot ready
extends PanelContainer

@onready var speaker_label: Label = $VBoxContainer/SpeakerLabel
@onready var text_label:    Label = $VBoxContainer/TextLabel

# --- Typewriter ---
var _full_text: String    = ""
var _shown_chars: int     = 0
var _typing: bool         = false
var _type_speed: float    = 0.03
var _type_timer: float    = 0.0

func _ready() -> void:
	DialogueUI.register_box(self)
	_apply_style()

func _apply_style() -> void:
	# DialogueRoot paints the background; keep this panel transparent.
	$".".add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	speaker_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	text_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Display source text and optional translation with the existing typewriter.
func display(speaker: String, text: String, translation: String = "") -> void:
	speaker_label.text = TextUtil.resolve_speaker(speaker)
	_full_text = TextUtil.resolve(text)
	var clean_translation := TextUtil.resolve(translation).strip_edges()
	if not clean_translation.is_empty():
		_full_text += "\n" + clean_translation
	_shown_chars = 0
	_type_timer = 0.0
	if _full_text.strip_edges().is_empty():
		# Never silently render an empty dialogue panel when authored data is
		# missing its text field. Log the bad line and keep UI visibly diagnosable.
		push_warning("DialogueBox.display received an empty dialogue line for speaker '%s'." % speaker)
		_typing = false
		text_label.text = "…"
	else:
		_typing = true
		text_label.text = ""
	DialogueUI._root.refresh_layout() if DialogueUI._root != null else null

func _process(delta: float) -> void:
	if not _typing:
		return
	_type_timer += delta
	if _type_timer >= _type_speed:
		_type_timer = 0.0
		_shown_chars += 1
		text_label.text = _full_text.left(_shown_chars)
		if _shown_chars >= _full_text.length():
			_typing = false
			if DialogueUI._root != null:
				DialogueUI._root.refresh_layout()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not event.is_action_pressed("interact"):
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
		_typing = false
		text_label.text = _full_text
	else:
		DialogueUI.player_pressed_advance()
	get_viewport().set_input_as_handled()

var _last_input_frame: int = -1

func _on_gui_input(event: InputEvent) -> void:
	var is_press = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not is_press:
		return
	# Godot can emit touch and synthetic mouse input in one frame. Ignore the duplicate.
	var frame := Engine.get_process_frames()
	if frame == _last_input_frame:
		return
	_last_input_frame = frame
	_dialogue_input()
