# papaJobert.gd
extends CharacterBody2D

@export var actor_id: String = ""
## ChapterLoader lookup -- override per-scene instance, don't hardcode here.
@export var dialogue_chapter: String = "chapter1"
@export var dialogue_scene_key: String = "scene_1_grandma_s_terrace"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	call_deferred("_register")

func _on_interacted(_interactor: Node) -> void:
	dialogue.dialogue_lines = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
	dialogue.start_dialogue()
	
func _register() -> void:
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
