# InteractableComponent — attach to any Node2D to make it interactable
# Parent must have Area2D child named "InteractArea"
class_name InteractableComponent
extends Node

signal interacted(interactor: Node)

@export var interact_label: String = "Talk"
var _in_range: bool = false
var _player_ref: Node = null

func _ready() -> void:
	# Expects sibling Area2D named InteractArea on parent
	var area = get_parent().get_node_or_null("InteractArea")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _in_range and event.is_action_pressed("interact"):
		interacted.emit(_player_ref)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = true
		_player_ref = body
		# TODO: show interact prompt UI

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = false
		_player_ref = null
