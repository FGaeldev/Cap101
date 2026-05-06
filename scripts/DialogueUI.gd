# DialogueUI.gd — Controls dialogue box UI, decoupled from NPCs
extends Node

var _current_component = null
var _dialogue_box = null

func register_box(box: Control) -> void:
	_dialogue_box = box

func show_line(speaker: String, text: String, component) -> void:
	_current_component = component
	if _dialogue_box:
		_dialogue_box.display(speaker, text)

func hide() -> void:
	_current_component = null
	if _dialogue_box:
		_dialogue_box.visible = false

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()
