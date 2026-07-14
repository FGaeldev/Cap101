# papaJobert.gd
extends CharacterBody2D

@export var actor_id: String = ""
@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	call_deferred("_register")
	visible = false
	global_position = Vector2(605, 62)

func _on_interacted(_interactor: Node) -> void:
	##print("interacted fired")
	##print("dialogue lines: ", dialogue.dialogue_lines)
	dialogue.dialogue_lines = ChapterLoader.get_scene_lines("chapter1", "scene_1_grandma_s_terrace")
	dialogue.start_dialogue()
	
func _register() -> void:
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
