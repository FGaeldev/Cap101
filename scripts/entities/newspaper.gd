# newspaper.gd -- the daily paper on the Aklan living room table. Opens
# newspaper_panel.gd through DialogueUI; connects sibling InteractableComponent.
extends Sprite2D

@onready var interactable: InteractableComponent = $InteractableComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	if not DialogueUI.is_active():
		DialogueUI.show_newspaper()
