# NPC_Elder.gd
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite2D

@export var actor_id: String = ""
## Quest/task/flag this NPC is imperative to. All optional, checked in that
## order by Comp_Interactable.refresh_quest_marker. Fill quest_id in when a
## real quest exists for her again.
@export var quest_id: String = ""
@export var task_id: String = ""
@export var task_step: int = -1
## Marker shows until the intro cutscene (chapter1_scene1) has played once.
@export var show_until_flag: String = "seen_chapter1_scene1"
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

enum FacingDirection {
	DOWN,
	UP,
	LEFT,
	RIGHT
}

@export var spawn_direction: FacingDirection = FacingDirection.DOWN

## Rapport/patience key AND dialogue "speaker" string match this exactly
## (GameState.rapport is keyed by speaker name, see Comp_Dialogue._last_speaker).
## Was previously never set anywhere -- idle pool rapport-tier lookup was
## silently reading rapport for "" the whole time.
@export var npc_id: String = "Lola Jonabel"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	
	_set_spawn_direction()
	
	dialogue.npc_id = npc_id
	interactable.interacted.connect(_on_interacted)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
		
func _set_spawn_direction() -> void:
	match spawn_direction:
		FacingDirection.DOWN:
			sprite.flip_h = false
			sprite.play("idle_down")

		FacingDirection.UP:
			sprite.flip_h = false
			sprite.play("idle_up")

		FacingDirection.LEFT:
			sprite.flip_h = true
			sprite.play("idle_side")

		FacingDirection.RIGHT:
			sprite.flip_h = false
			sprite.play("idle_side")

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
