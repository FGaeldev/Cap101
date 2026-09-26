# bedroom_book.gd — Chapter 1 tutorial object: the Book on the bedroom desk.
#
# Flow (data-driven pieces live elsewhere, this script is only the glue):
#   1. Scene 1 cutscene sets "seen_chapter1_scene1" -> QuestManager unlocks q002
#      (quest_data.json "requires_flag") -> Game.gd shows the quest-HUD message.
#   2. Player returns here and interacts with the book:
#        q002 completes, "book_ui" tutorial starts, BookUI opens.
#   3. When the "book_ui" tutorial finishes, story continues to the airport
#      (scene_2), same destination the old cutscene used to auto-load.
#
# The book is fully inert (no interact prompt, no HUD button) until scene 1 is
# done AND q002 is active/done, so it can't be used to skip ahead.
# Follows the standard sibling-component wiring pattern (TDD §3): connect
# InteractableComponent.interacted, keep logic tiny, delegate to autoloads.
extends Sprite2D

## Story gate: Scene 1 cutscene's set_flag. Checked directly (not only via
## q002's requires_flag) so a stale/dev-set quest state can't open the book early.
const SCENE1_DONE_FLAG: String = "seen_chapter1_scene1"
const BOOK_QUEST_ID: String = "q002"
## Must match "completion_flag" of BOOK_QUEST_ID in data/quest_data.json.
const BOOK_QUEST_DONE_FLAG: String = "quest_002_done"
const BOOK_TUTORIAL_ID: String = "book_ui"

## Quest/task this object is imperative to. Read by its InteractableComponent
## (Comp_Interactable.refresh_quest_marker). Same id as BOOK_QUEST_ID.
@export var quest_id: String = BOOK_QUEST_ID
@export var task_id: String = ""
## -1 = any active step of task_id.
@export var task_step: int = -1
## Not "settings": tutorial step 1 ("Tap the Settings tab") waits for the
## player to tap Settings; opening on that tab would satisfy it instantly.
const BOOK_START_TAB: String = "bucket_list"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var interact_area: Area2D = $InteractableComponent/InteractArea


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	QuestManager.quest_started.connect(_refresh_availability)
	_refresh_availability()


func _is_available() -> bool:
	if not GameState.get_flag(SCENE1_DONE_FLAG):
		return false
	return BOOK_QUEST_ID in QuestManager.active_quests \
		or GameState.get_flag(BOOK_QUEST_DONE_FLAG)


## Toggles the InteractArea itself: while monitoring is off the player never
## enters the interactable's range pool, so no prompt / HUD interact button.
func _refresh_availability(_quest_id: String = "") -> void:
	interact_area.set_deferred("monitoring", _is_available())


func _on_interacted(_interactor: Node = null) -> void:
	if not _is_available():
		return
	if BOOK_QUEST_ID in QuestManager.active_quests:
		QuestManager.complete_quest(BOOK_QUEST_ID)

	# Idempotent: no-op if tutorial already done, another is running, or dev
	# mode. Must start BEFORE BookUI.open() so tab notifications reach it.
	TutorialManager.start(BOOK_TUTORIAL_ID)
	BookUI.open(BOOK_START_TAB)
