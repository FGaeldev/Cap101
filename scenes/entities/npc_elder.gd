# NPC_Elder.gd
extends CharacterBody2D

@export var actor_id: String = ""
@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)

func _on_interacted(_interactor: Node) -> void:
	if not GameState.get_flag("seen_chapter1_scene1"):
		CutsceneManager.play("chapter1_scene1")
	else:
		dialogue.dialogue_lines = ChapterLoader.get_scene_lines("chapter1", "scene_1_part1")
		dialogue.start_dialogue()
