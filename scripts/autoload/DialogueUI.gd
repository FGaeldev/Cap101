# DialogueUI.gd
extends Node

signal dialogue_finished

var _current_component = null
var _dialogue_box      = null
var _choice_box        = null
var _root              = null

func register_box(box: Control) -> void:
	_dialogue_box = box

func register_choice_box(box: Control) -> void:
	_choice_box = box

func register_root(root: Control) -> void:
	_root = root

func show_line(speaker: String, text: String, component) -> void:
	_current_component = component
	if _dialogue_box:
		_dialogue_box.display(speaker, text)
	if _root:
		_root.show_box()
		# Portrait is optional per-NPC art (DialogueComponent.portrait). Missing
		# export just means no portrait texture assigned yet -> hides cleanly.
		_root.set_portrait(component.get("portrait"))

func show_choices(choices: Array, component) -> void:
	if _choice_box:
		_choice_box.show_choices(choices, component)

func hide() -> void:
	_current_component = null
	if _choice_box:
		_choice_box.hide_choices()
	if _root:
		_root.hide_box()
	dialogue_finished.emit()

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()
