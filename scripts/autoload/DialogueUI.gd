# DialogueUI.gd
extends Node

signal dialogue_finished
signal challenge_gate_entered(challenge_id: String)

var _current_component = null
var _dialogue_box      = null
var _choice_box        = null
var _root              = null
var _phrase_box        = null   # lazily instantiated phrase_builder panel
var _quiz_box          = null   # lazily instantiated quiz_panel
var _minigame_box      = null   # lazily instantiated minigame panel (one at a time)
var _minigame_type: String = ""   # minigame_type of the live _minigame_box

const PHRASE_BUILDER_SCENE := preload("res://scenes/ui/phrase_builder.tscn")
const QUIZ_PANEL_SCENE := preload("res://scenes/ui/quiz_panel.tscn")
## minigame_type -> panel script. Hardcoded (no dir scan: DirAccess is unreliable
## in exported Android builds, TDD 9.1). New minigame = add one entry here.
const MINIGAME_SCRIPTS := {
	"memory_match": preload("res://scripts/ui/memory_match_panel.gd"),
}

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
	if _quiz_box and is_instance_valid(_quiz_box):
		_quiz_box.close()
	if _minigame_box and is_instance_valid(_minigame_box):
		_minigame_box.close()
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
	if _quiz_box and is_instance_valid(_quiz_box):
		_quiz_box.close()
	if _minigame_box and is_instance_valid(_minigame_box):
		_minigame_box.close()
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

## Shows the quiz panel for one "quiz" dialogue line. Lazy-instantiated as a
## sibling of DialogueRoot, same as phrase_builder. Result goes to the owning
## DialogueComponent, which picks the success/failure line index.
func show_quiz(line: Dictionary, component) -> void:
	_current_component = component
	if _quiz_box == null or not is_instance_valid(_quiz_box):
		if _root == null:
			push_error("DialogueUI: no root registered, cannot show quiz")
			return
		_quiz_box = QUIZ_PANEL_SCENE.instantiate()
		_root.get_parent().add_child(_quiz_box)
	# Drop stale one-shots left by a quiz closed without resolving, else the
	# next resolve would also fire the old component's handler.
	for conn in _quiz_box.resolved.get_connections():
		_quiz_box.resolved.disconnect(conn["callable"])
	_quiz_box.resolved.connect(func(passed: bool):
		_quiz_box.close()
		component.resolve_quiz(passed)
	, CONNECT_ONE_SHOT)
	_quiz_box.open(line)

## Shows the minigame named by line["minigame_type"]. Lazy-instantiated as a
## sibling of DialogueRoot. Unknown type resolves as a pass so the story never
## softlocks on bad data (no-punishment rule). Result goes to the owning
## DialogueComponent, which picks the success/failure line index.
func show_minigame(line: Dictionary, component) -> void:
	_current_component = component
	var mg_type: String = str(line.get("minigame_type", ""))
	if not MINIGAME_SCRIPTS.has(mg_type):
		push_error("DialogueUI: unknown minigame_type '%s', auto-passing." % mg_type)
		component.call_deferred("resolve_minigame", true)
		return
	if _root == null:
		push_error("DialogueUI: no root registered, cannot show minigame")
		return

	# Reuse the live panel only if it is the same type; otherwise rebuild.
	if _minigame_box == null or not is_instance_valid(_minigame_box) or _minigame_type != mg_type:
		if _minigame_box and is_instance_valid(_minigame_box):
			_minigame_box.queue_free()
		_minigame_box = MINIGAME_SCRIPTS[mg_type].new()
		_minigame_type = mg_type
		_root.get_parent().add_child(_minigame_box)

	# Drop stale one-shots left by a minigame closed without resolving.
	for conn in _minigame_box.resolved.get_connections():
		_minigame_box.resolved.disconnect(conn["callable"])
	_minigame_box.resolved.connect(func(passed: bool):
		_minigame_box.close()
		component.resolve_minigame(passed)
	, CONNECT_ONE_SHOT)
	_minigame_box.open(line)

func player_pressed_advance() -> void:
	if _current_component:
		_current_component.advance()

## True while dialogue box is visible; HUD uses this to hide gameplay controls.
func is_active() -> bool:
	return _root != null and _root.visible
