# bedroom_book.gd — Chapter 1 tutorial object: the Book on the bedroom desk.
#
# Flow (data-driven pieces live elsewhere, this script is only the glue):
#   1. Scene 1 cutscene sets "seen_chapter1_scene1" -> QuestManager unlocks q002.
#   2. Player interacts with the book; "book_ui" tutorial starts and BookUI opens.
#   3. Only after the tutorial finishes does q002 complete and show its popup.
#
# The book stays inert until scene 1 is done and q002 is active or completed.
# Connects sibling InteractableComponent and delegates state to autoloads.
extends Sprite2D

## Story gate: Scene 1 cutscene's set_flag.
const SCENE1_DONE_FLAG: String = "seen_chapter1_scene1"
const BOOK_QUEST_ID: String = "q002"
## Must match "completion_flag" of BOOK_QUEST_ID in data/quest_data.json.
const BOOK_QUEST_DONE_FLAG: String = "quest_002_done"
const BOOK_TUTORIAL_ID: String = "book_ui"

## Quest/task this object is imperative to. Read by InteractableComponent.
@export var quest_id: String = BOOK_QUEST_ID
@export var task_id: String = ""
## -1 = any active step of task_id.
@export var task_step: int = -1

## Avoid auto-completing tutorial's first step by opening directly on Settings.
const BOOK_START_TAB: String = "bucket_list"

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var interact_area: Area2D = $InteractableComponent/InteractArea


func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	QuestManager.quest_started.connect(_refresh_availability)
	TutorialManager.tutorial_completed.connect(_on_tutorial_completed)
	_refresh_availability()


func _is_available() -> bool:
	if not GameState.get_flag(SCENE1_DONE_FLAG):
		return false
	return BOOK_QUEST_ID in QuestManager.active_quests \
		or GameState.get_flag(BOOK_QUEST_DONE_FLAG)


## Toggle InteractArea so unavailable book cannot enter the player's range pool.
func _refresh_availability(_quest_id: String = "") -> void:
	interact_area.set_deferred("monitoring", _is_available())


func _on_interacted(_interactor: Node = null) -> void:
	if not _is_available():
		return

	# Start tutorial before opening BookUI so tab notifications reach it.
	TutorialManager.start(BOOK_TUTORIAL_ID)
	BookUI.open(BOOK_START_TAB)


## Complete the book quest only after the player finishes the full tutorial.
## Early close aborts the tutorial and leaves q002 active for the next attempt.
func _on_tutorial_completed(tutorial_id: String) -> void:
	if tutorial_id != BOOK_TUTORIAL_ID:
		return
	if BOOK_QUEST_ID in QuestManager.active_quests:
		QuestManager.complete_quest(BOOK_QUEST_ID)
