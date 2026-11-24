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
## Shop this NPC runs (data/items.json "shops"). Adds "Buy" to the menu while
## the player is in that shop's area. Empty = not a vendor.
@export var shop_id: String = ""
## A minigame this NPC offers in their menu ("plaza_directions": plaza_game.gd).
## Set from data/culture_spots.json "activity". Empty = none.
@export var activity: String = ""

const SideQuests := preload("res://scripts/util/side_quests.gd")
const StallHelper := preload("res://scripts/util/stall_helper.gd")
const PlazaGame := preload("res://scripts/util/plaza_game.gd")

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
	# Rose called the player over after a warp attempt: ask where to go.
	if TourGuide.take_pending_ask(self):
		return
	# A finished errand is handed in first, even where a talk cutscene would play.
	var hand_in: Array = SideQuests.hand_in_lines_for(npc_id)
	if not hand_in.is_empty():
		dialogue.dialogue_lines = hand_in
		dialogue.start_dialogue()
		return
	if not cutscene_id.is_empty() and not GameState.get_flag(cutscene_seen_flag):
		CutsceneManager.play(cutscene_id)
		return
	var extras: Array = []
	if not Economy.shop_here(shop_id).is_empty():
		extras.append({"id": "shop", "label": "Buy"})
		if bool(Economy.shops.get(shop_id, {}).get("helper", false)) and StallHelper.is_available():
			extras.append({"id": "stall", "label": "Help at the stall"})
	if activity == "plaza_directions" and not PlazaGame.done_today():
		extras.append({"id": "plaza_directions", "label": "Help with directions"})
	# Out with Rose and nothing required here: she can take the player elsewhere.
	if npc_id == TourGuide.ROSE_ID and TourGuide.can_offer_trip(self):
		extras.append({"id": "go_somewhere", "label": "Let's go somewhere"})
	DialogueUI.show_npc_interaction_menu(
		npc_id if not npc_id.is_empty() else name,
		Callable(self, "_on_interaction_menu_choice"),
		extras
	)


## Routes menu choices without changing the existing story/idle dialogue path.
func _on_interaction_menu_choice(choice: String) -> void:
	match choice:
		"talk":
			_start_dialogue_or_idle()
		"review":
			DialogueUI.show_review()
		"shop":
			Economy.open_shop(shop_id)
		"stall":
			StallHelper.start(self)
		"plaza_directions":
			PlazaGame.start(self)
		"go_somewhere":
			TourGuide.ask(self)
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
		return
	# A side quest this NPC gives (offer, reminder or hand-in) comes before idle talk.
	var quest_lines: Array = SideQuests.lines_for(npc_id)
	if not quest_lines.is_empty():
		dialogue.dialogue_lines = quest_lines
		dialogue.start_dialogue()
	else:
		dialogue.start_idle_dialogue()

func _on_dialogue_ended() -> void:
	if not story_done_flag.is_empty() and not GameState.get_flag(story_done_flag):
		GameState.set_flag(story_done_flag)

func _register() -> void:
	if not actor_id.is_empty():
		CutsceneManager.register_actor(actor_id, self)
