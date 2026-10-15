# npc_generic.gd
## Data-driven NPC shell. Story dialogue plays until it finishes once, then
## idle pool takes over on re-interact. All per-NPC values are exports --
## override on the scene root, do not fork this script per NPC.
## Missing dialogue key / idle pool is safe: story path ends immediately,
## idle path no-ops (see ChapterLoader + Comp_Dialogue).
extends CharacterBody2D

## CutsceneManager registry id. Empty = not cutscene-controllable.
@export var actor_id: String = ""
## Rapport/patience key AND dialogue "speaker" string. Must match exactly
## (GameState.rapport is keyed by speaker name, see Comp_Dialogue._last_speaker).
@export var npc_id: String = ""
## ChapterLoader lookup: data/dialogue/<dialogue_chapter>.json -> dialogue_scene_key.
@export var dialogue_chapter: String = "chapter1"
@export var dialogue_scene_key: String = ""
## Sibling key in dialogue_chapter JSON. Empty = story dialogue replays every interact.
@export var idle_pool_key: String = ""
## Set when story dialogue completes once; flips interact to idle pool.
@export var story_done_flag: String = ""

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	dialogue.npc_id = npc_id
	interactable.interacted.connect(_on_interacted)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	call_deferred("_register")

func _on_interacted(_interactor: Node) -> void:
	if idle_pool_key.is_empty() or story_done_flag.is_empty() or not GameState.get_flag(story_done_flag):
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
