# npc_generic.gd
## Data-driven NPC shell. Story dialogue plays until it finishes once, then
## generated idle talk takes over on re-interact. All per-NPC values are exports --
## override on the scene root, do not fork this script per NPC.
## A missing dialogue key is safe: goes straight to idle talk.
extends CharacterBody2D

## CutsceneManager registry id. Empty = not cutscene-controllable.
@export var actor_id: String = ""
## Rapport/patience key AND dialogue "speaker" string. Must match exactly
## (GameState.rapport is keyed by speaker name, see Comp_Dialogue._last_speaker).
@export var npc_id: String = ""
## ChapterLoader lookup: data/dialogue/<dialogue_chapter>.json -> dialogue_scene_key.
@export var dialogue_chapter: String = "chapter1"
@export var dialogue_scene_key: String = ""
## Set when story dialogue completes once; flips interact to generated idle talk (IdleTalk).
@export var story_done_flag: String = ""
## Optional quest link. While this quest is active, Comp_Interactable shows
## the quest marker over the NPC (read via get() on the parent).
@export var quest_id: String = ""
## Quest completed the first time the player interacts with this NPC
## (idempotent in QuestManager). Empty = this NPC never triggers a quest.
@export var interact_quest_id: String = ""
## data/cutscenes/<cutscene_id>.json plays INSTEAD of story dialogue until
## cutscene_seen_flag is set (the cutscene must set that flag itself).
@export var cutscene_id: String = ""
@export var cutscene_seen_flag: String = ""
## Interaction is ignored until this flag is set. Empty = always interactable.
@export var unlock_flag: String = ""

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	dialogue.npc_id = npc_id
	interactable.interacted.connect(_on_interacted)
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	call_deferred("_register")

func _on_interacted(_interactor: Node) -> void:
	if not unlock_flag.is_empty() and not GameState.get_flag(unlock_flag):
		return
	if not interact_quest_id.is_empty():
		QuestManager.complete_quest(interact_quest_id)
	if not cutscene_id.is_empty() and not GameState.get_flag(cutscene_seen_flag):
		CutsceneManager.play(cutscene_id)
		return
	DialogueUI.show_npc_interaction_menu(
		npc_id if not npc_id.is_empty() else name,
		Callable(self, "_on_interaction_menu_choice")
	)


## Routes menu choices without changing the existing story/idle dialogue path.
func _on_interaction_menu_choice(choice: String) -> void:
	match choice:
		"talk":
			_start_dialogue_or_idle()
		"review":
			DialogueUI.show_review()
		"goodbye":
			return


func _start_dialogue_or_idle() -> void:
	var story_lines: Array = ChapterLoader.get_scene_lines(dialogue_chapter, dialogue_scene_key)
	# No authored story lines -> go straight to idle instead of closing silently.
	var story_pending: bool = not story_lines.is_empty() \
			and (story_done_flag.is_empty() or not GameState.get_flag(story_done_flag))
	if story_pending:
		dialogue.dialogue_lines = story_lines
		dialogue.start_dialogue()
	else:
		dialogue.start_idle_dialogue()

func _on_dialogue_ended() -> void:
	if not story_done_flag.is_empty() and not GameState.get_flag(story_done_flag):
		GameState.set_flag(story_done_flag)

func _register() -> void:
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
