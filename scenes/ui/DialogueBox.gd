# DialogueBox.gd — typewriter effect, portrait slot ready
extends PanelContainer

@onready var speaker_label: Label = $VBoxContainer/SpeakerLabel
@onready var text_label:    Label = $VBoxContainer/TextLabel

# --- Typewriter ---
var _full_text: String    = ""
var _shown_chars: int     = 0
var _typing: bool         = false
var _type_speed: float    = 0.03   # seconds per character
var _type_timer: float    = 0.0

func _ready() -> void:
	DialogueUI.register_box(self)
	visible = false
	_apply_style()

func _apply_style() -> void:
	$".".add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())
	speaker_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	text_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)

func display(speaker: String, text: String) -> void:
	speaker_label.text = "[ %s ]" % speaker
	# Start typewriter
	_full_text    = text
	_shown_chars  = 0
	_typing       = true
	_type_timer   = 0.0
	text_label.text = ""
	visible = true

func _process(delta: float) -> void:
	if not _typing: return
	_type_timer += delta
	if _type_timer >= _type_speed:
		_type_timer = 0.0
		_shown_chars += 1
		text_label.text = _full_text.left(_shown_chars)
		if _shown_chars >= _full_text.length():
			_typing = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if not event.is_action_pressed("interact"): return

	if _typing:
		# First press = skip typewriter, show full text
		_typing = false
		text_label.text = _full_text
	else:
		# Second press = advance
		DialogueUI.player_pressed_advance()
	get_viewport().set_input_as_handled()
