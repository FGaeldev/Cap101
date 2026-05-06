# NPC_Elder.gd
extends CharacterBody2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	
	# Set dialogue here, skip inspector
	dialogue.dialogue_lines = [
		{ "speaker": "Lolo Berto", "text": "Maayong aga! Kumusta ka?", "word_id": "w001" },
		{ "speaker": "Lolo Berto", "text": "Salamat sa pag-bisita.", "word_id": "w003" }
	]
	dialogue.npc_id = "npc_elder"

func _on_interacted(_interactor: Node) -> void:
	dialogue.start_dialogue()
