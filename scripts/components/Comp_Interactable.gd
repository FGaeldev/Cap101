# InteractableComponent — attach to any Node2D to make it interactable
# Parent must have Area2D child named "InteractArea"
class_name InteractableComponent
extends Node

signal interacted(interactor: Node)

@export var interact_label: String = "Talk"
## Optional. If set, fires QuestManager.complete_quests_with_trigger(trigger_on_enter)
## once when player enters this InteractArea. Empty = no trigger (default, most NPCs).
@export var trigger_on_enter: String = ""
var _in_range: bool = false
var _player_ref: Node = null

func _ready() -> void:
	# Expects sibling Area2D named InteractArea on parent
	var area = get_parent().get_node_or_null("InteractArea")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		area.input_event.connect(_on_input_event)

func _unhandled_input(event: InputEvent) -> void:
	if not _in_range or CutsceneManager.is_playing():
		return
	if not get_parent().is_visible_in_tree():
		return
	if event.is_action_pressed("interact"):
		interacted.emit(_player_ref)
		
func _on_input_event(_viewport, event, _shape_idx):
	if not _in_range or CutsceneManager.is_playing():
		return
	if not get_parent().is_visible_in_tree():
		return
	# project.godot sets pointing/emulate_touch_from_mouse=true (needed for
	# Android), which makes a single mouse click also synthesize an
	# InputEventScreenTouch. Checking both event types here double-fired
	# `interacted` per click. Touch alone covers real touch AND the
	# emulated-from-mouse case, so this is the single source now.
	if event is InputEventScreenTouch and event.pressed:
		interacted.emit(_player_ref)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = true
		_player_ref = body
		if not trigger_on_enter.is_empty():
			QuestManager.complete_quests_with_trigger(trigger_on_enter)
		# TODO: show interact prompt UI

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = false
		_player_ref = null
