# letter_keyboard.gd -- on-screen QWERTY for letter minigames (hangman, crossword).
# Touch devices have no keyboard; panels also accept physical keys through
# key_to_letter so desktop play doesn't need to click every letter.
class_name LetterKeyboard
extends VBoxContainer

signal letter_pressed(letter: String)
signal erase_pressed

const ROWS: Array[String] = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KEY_MIN_HEIGHT: float = 24.0
const KEY_SEPARATION: int = 2
const ERASE_LABEL: String = "Del"

var _keys: Dictionary = {}   # letter -> Button

## show_erase adds a Del key to the last row.
func _init(show_erase: bool = false) -> void:
	add_theme_constant_override("separation", KEY_SEPARATION)
	for row_letters in ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", KEY_SEPARATION)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(row)
		for letter in row_letters:
			var key := _make_key(letter)
			key.pressed.connect(func(): letter_pressed.emit(letter))
			row.add_child(key)
			_keys[letter] = key
		if show_erase and row_letters == ROWS[-1]:
			var erase := _make_key(ERASE_LABEL)
			erase.pressed.connect(func(): erase_pressed.emit())
			row.add_child(erase)

func _make_key(label: String) -> Button:
	var key := Button.new()
	key.text = label
	key.focus_mode = Control.FOCUS_NONE
	key.custom_minimum_size = Vector2(0, KEY_MIN_HEIGHT)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key.size_flags_stretch_ratio = 1.0 if label.length() == 1 else 2.0
	UIThemeApplier.apply_button_theme(key, "primary")
	key.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	return key

## Re-enables every key.
func reset() -> void:
	for key in _keys.values():
		key.disabled = false
		key.modulate = Color.WHITE

## Disables a guessed letter, tinted to show whether it was right (hangman).
func mark_used(letter: String, color: Color) -> void:
	var key: Button = _keys.get(letter)
	if key == null:
		return
	key.disabled = true
	key.modulate = Color(color.r, color.g, color.b, 0.6)

## The letter a physical key event types, or "" if it isn't A-Z.
static func key_to_letter(event: InputEventKey) -> String:
	if event.keycode >= KEY_A and event.keycode <= KEY_Z:
		return String.chr(event.keycode)
	return ""
