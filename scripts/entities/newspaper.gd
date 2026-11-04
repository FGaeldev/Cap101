# newspaper.gd -- the daily paper on the Aklan living room table. Opens
# newspaper_panel.gd through DialogueUI; connects sibling InteractableComponent.
# The marker shows until today's puzzle is solved and comes back each new day.
extends Sprite2D

@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	DayNightManager.day_changed.connect(_refresh_marker)
	DialogueUI.dialogue_finished.connect(_refresh_marker)
	_refresh_marker()

func _on_interacted(_interactor: Node) -> void:
	if not DialogueUI.is_active():
		DialogueUI.show_newspaper()

func _refresh_marker() -> void:
	interactable.is_active = not GameState.is_puzzle_solved_today()
	interactable.refresh_quest_marker()
