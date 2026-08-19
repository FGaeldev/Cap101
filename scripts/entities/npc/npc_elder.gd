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
## Idle pool key (ChapterLoader.get_idle_pool), sibling key in dialogue_chapter's
## JSON. Empty = no idle content yet, repeat dialogue plays every interact
## (old behavior, safe fallback).
@export var idle_pool_key: String = "idle_pool_lola_jonabel"
## Set once the post-cutscene repeat dialogue has played to completion once.
## Subsequent interacts draw from idle_pool_key instead of replaying it.
@export var story_done_flag: String = "story_done_lola_jonabel_scene1"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)

func _on_interacted(_interactor: Node) -> void:
	if not GameState.get_flag(seen_flag):
		CutsceneManager.play(cutscene_id)
	elif idle_pool_key.is_empty() or not GameState.get_flag(story_done_flag):
		dialogue.dialogue_lines = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
		dialogue.start_dialogue()
	else:
		dialogue.start_idle_dialogue(ChapterLoader.get_idle_pool(dialogue_chapter, idle_pool_key))

## Only the post-cutscene repeat dialogue should ever set story_done_flag --
## idle dialogue also fires dialogue_ended, but story_done_flag is already
## true by then, so this is a no-op on that path (guarded, not re-checked).
func _on_dialogue_ended() -> void:
	if GameState.get_flag(seen_flag) and not story_done_flag.is_empty() and not GameState.get_flag(story_done_flag):
		GameState.set_flag(story_done_flag)
