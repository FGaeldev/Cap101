# DialogueUI.gd
extends Node

var _current_component = null
var _dialogue_box      = null
var _choice_box        = null

func register_box(box: Control) -> void:
	_dialogue_box = box

func register_choice_box(box: Control) -> void:
	_choice_box = box

func show_line(speaker: String, text: String, component) -> void:
	_current_component = component
	if _dialogue_box:
		_dialogue_box.display(speaker, text)

func show_choices(choices: Array, component) -> void:
	if _choice_box:
		_choice_box.show_choices(choices, component)

func hide() -> void:
	_current_component = null
	if _dialogue_box:
		_dialogue_box.visible = false
	if _choice_box:
		_choice_box.hide_choices()

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()
