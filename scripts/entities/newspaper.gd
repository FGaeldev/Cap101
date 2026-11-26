# newspaper.gd -- the daily paper on the Aklan living room table. Opens
# newspaper_panel.gd through DialogueUI; connects sibling InteractableComponent.
# The marker shows until today's puzzle is solved and comes back each new day.
extends Sprite2D

const NewspaperPanel := preload("res://scripts/ui/newspaper_panel.gd")

@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	DayNightManager.daily_reset.connect(_refresh_marker)
	DialogueUI.dialogue_finished.connect(_refresh_marker)
	_refresh_marker()

func _on_interacted(_interactor: Node) -> void:
	if not DialogueUI.is_active():
		DialogueUI.show_newspaper()
		TutorialManager.start("newspaper")

func _refresh_marker() -> void:
	# Not while the paper says "Learn more words to play": nothing to do there.
	interactable.is_active = NewspaperPanel.puzzle_open_today()
	interactable.refresh_quest_marker()
