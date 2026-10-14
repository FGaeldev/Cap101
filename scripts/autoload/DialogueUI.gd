# DialogueUI.gd
extends Node

signal dialogue_finished
signal challenge_gate_entered(challenge_id: String)

var _current_component = null
var _dialogue_box      = null
var _choice_box        = null
var _root              = null
var _phrase_box        = null   # lazily instantiated phrase_builder panel

const PHRASE_BUILDER_SCENE := preload("res://scenes/ui/phrase_builder.tscn")

func register_box(box: Control) -> void:
	_dialogue_box = box

func register_choice_box(box: Control) -> void:
	_choice_box = box

func register_root(root: Control) -> void:
	_root = root

## Display dialogue text and its optional authored translation.
func show_line(
	speaker: String,
	text: String,
	component,
	portrait_tex,
	translation: String = ""
) -> void:
	_current_component = component
	if _dialogue_box:
		_dialogue_box.display(speaker, text, translation)
	if _root:
		_root.show_box()
		# Portrait is optional per-NPC art. Missing art hides cleanly.
		_root.set_portrait(portrait_tex)

func show_choices(choices: Array, component) -> void:
	if _choice_box:
		_choice_box.show_choices(choices, component)

func hide() -> void:
	if _phrase_box and is_instance_valid(_phrase_box):
		_phrase_box.close()
	_current_component = null
	if _choice_box:
		_choice_box.hide_choices()
	if _root:
		_root.hide_box()
	dialogue_finished.emit()

## Hide visuals without ending the dialogue session; challenge gates use this pause.
func hide_box_only() -> void:
	if _phrase_box and is_instance_valid(_phrase_box):
		_phrase_box.close()
	if _choice_box:
		_choice_box.hide_choices()
	if _root:
		_root.hide_box()

## Shows the phrase_builder panel for one dialogue line. Instantiated lazily as
## a sibling of DialogueRoot (UILayer), so Game.tscn needs no edit. Result is
## forwarded to the owning DialogueComponent, which picks success/failure line.
func show_phrase_builder(line: Dictionary, component) -> void:
	_current_component = component
	if _phrase_box == null or not is_instance_valid(_phrase_box):
		if _root == null:
			push_error("DialogueUI: no root registered, cannot show phrase builder")
			return
		_phrase_box = PHRASE_BUILDER_SCENE.instantiate()
		_root.get_parent().add_child(_phrase_box)
	_phrase_box.resolved.connect(func(passed: bool):
		_phrase_box.close()
		component.resolve_phrase_builder(passed)
	, CONNECT_ONE_SHOT)
	_phrase_box.open(line)

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()

## True while dialogue box is visible; HUD uses this to hide gameplay controls.
func is_active() -> bool:
	return _root != null and _root.visible
