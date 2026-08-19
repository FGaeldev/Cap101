# papaJobert.gd
extends CharacterBody2D

@export var actor_id: String = ""
## ChapterLoader lookup -- override per-scene instance, don't hardcode here.
@export var dialogue_chapter: String = "chapter1"
@export var dialogue_scene_key: String = "scene_1_grandma_s_terrace"
## Idle pool key (ChapterLoader.get_idle_pool), sibling key in dialogue_chapter's
## JSON. Empty = no idle content yet, story dialogue plays every interact
## (old behavior, safe fallback).
@export var idle_pool_key: String = "idle_pool_papa_jobert"
## Set once dialogue_scene_key has played to completion once. Subsequent
## interacts draw from idle_pool_key instead of replaying it.
@export var story_done_flag: String = "story_done_papa_jobert_scene1"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	call_deferred("_register")

func _on_interacted(_interactor: Node) -> void:
	if idle_pool_key.is_empty() or not GameState.get_flag(story_done_flag):
		dialogue.dialogue_lines = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
		dialogue.start_dialogue()
	else:
		dialogue.start_idle_dialogue(ChapterLoader.get_idle_pool(dialogue_chapter, idle_pool_key))

func _on_dialogue_ended() -> void:
	if not story_done_flag.is_empty() and not GameState.get_flag(story_done_flag):
		GameState.set_flag(story_done_flag)

func _register() -> void:
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
