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
## data/dialogue/<dialogue_chapter>.json sibling key "idle_pool_<this>" (GDD §6.9).
## Defaults to actor_id; override if the JSON key uses a different slug.
@export var idle_pool_npc_key: String = ""

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
	dialogue.npc_id = actor_id
	var pool_key: String = idle_pool_npc_key if not idle_pool_npc_key.is_empty() else actor_id
	dialogue.idle_pool = ChapterLoader.get_scene_lines(dialogue_chapter, "idle_pool_%s" % pool_key)

func _on_interacted(_interactor: Node) -> void:
	if not GameState.get_flag(seen_flag):
		CutsceneManager.play(cutscene_id)
	elif not dialogue.idle_pool.is_empty():
		# Story beat for this scene is exhausted (seen_flag already true) —
		# show ambient banter instead of replaying the same fixed lines
		# every re-interact (PROF_FEEDBACK_RESPONSE.md §1/§3, GDD §6.9).
		dialogue.start_idle_dialogue()
	else:
		dialogue.dialogue_lines = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
		dialogue.start_dialogue()
