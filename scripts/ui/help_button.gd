# help_button.gd -- the "?" button on every quiz, minigame and mechanic screen.
# Opens that screen's page from data/help_topics.json.
#
# Screens with a header row add it there:  row.add_child(HelpButton.new("crossword"))
# The rest pin it to their top right:      HelpButton.pin(self, "quiz")
class_name HelpButton
extends Button

const InstructionsPanel := preload("res://scripts/ui/instructions_panel.gd")

const BUTTON_SIZE := Vector2(24, 24)
## Gap to the panel's top right corner, clear of the corner art on panel frames.
const PIN_INSET := Vector2(10, 4)

var _topic: String = ""
var _panel: Control
var _shift := Vector2.ZERO


func _init(topic: String = "") -> void:
	_topic = topic
	text = "?"
	tooltip_text = "How this works"
	custom_minimum_size = BUTTON_SIZE
	# No focus: Space and Enter belong to the screen behind, such as a crossword.
	focus_mode = Control.FOCUS_NONE
	UIThemeApplier.apply_button_theme(self, "secondary")
	add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	pressed.connect(_on_pressed)


## Adds the button to a panel's top right corner, outside its layout so the
## panel's content stays exactly where it was.
## shift moves it from that spot, for panels with little room at the top.
static func pin(panel: Control, topic: String, shift: Vector2 = Vector2.ZERO) -> HelpButton:
	var button := HelpButton.new(topic)
	button._panel = panel
	button._shift = shift
	button.top_level = true
	panel.add_child(button)
	button.size = BUTTON_SIZE
	button._follow_panel()
	return button


## Every frame, not on the panel's rect signals: those don't fire when a parent
## moves the panel, as the dialogue panel does when it changes height.
func _process(_delta: float) -> void:
	if _panel != null and is_visible_in_tree():
		_follow_panel()


func _follow_panel() -> void:
	global_position = _panel.global_position + _shift + Vector2(_panel.size.x - BUTTON_SIZE.x - PIN_INSET.x, PIN_INSET.y)


func _on_pressed() -> void:
	AudioManager.play_sfx("menu_click")
	InstructionsPanel.open_topic(get_tree(), _topic)
