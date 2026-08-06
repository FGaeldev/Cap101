# NPC_Elder.gd
extends CharacterBody2D

@export var actor_id: String = ""
## First-play cutscene id (data/cutscenes/<id>.json), gated by seen_flag below.
@export var cutscene_id: String = "chapter1_scene1"
## ChapterLoader lookup for repeat-visit (post-cutscene) dialogue.
@export var dialogue_chapter: String = "chapter1"
@export var dialogue_scene_key: String = "scene_1_part1"
## GameState flag checked/set by the cutscene's own set_flag step -- must match
## the "flag" value inside data/cutscenes/<cutscene_id>.json exactly.
@export var seen_flag: String = "seen_chapter1_scene1"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)

func _on_interacted(_interactor: Node) -> void:
	if not GameState.get_flag(seen_flag):
		CutsceneManager.play(cutscene_id)
	else:
		dialogue.dialogue_lines = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
		dialogue.start_dialogue()
