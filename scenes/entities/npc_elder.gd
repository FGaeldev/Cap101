# NPC_Elder.gd
extends CharacterBody2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	
	# Set dialogue here, skip inspector
	dialogue.dialogue_lines = [
		{
  "speaker": "Lolo Berto",
  "text": "Ano ang buot mo?",
  "word_id": "",
  "choices": [
	{ "label": "Gusto ko makahibalo.", "next": 2 },
	{ "label": "Wala lang.", "next": 3 },
	{ "label": "Salamat, adto na ako.", "next": -1 }
  ]
}
	]
	dialogue.npc_id = "npc_elder"

func _on_interacted(_interactor: Node) -> void:
	print("interacted fired")
	print("dialogue lines: ", dialogue.dialogue_lines)
	dialogue.start_dialogue()
