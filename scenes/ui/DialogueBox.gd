# DialogueBox.gd
extends PanelContainer

@onready var speaker_label: Label = $VBoxContainer/SpeakerLabel
@onready var text_label: Label = $VBoxContainer/TextLabel

func _ready() -> void:
	DialogueUI.register_box(self)
	visible = false

func display(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	text_label.text = text
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact"):
		DialogueUI.player_pressed_advance()
		get_viewport().set_input_as_handled()
