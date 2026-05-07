# NPC_Elder.gd
extends CharacterBody2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	dialogue.npc_id = "npc_elder"
	dialogue.dialogue_lines = [
		{ "speaker": "Lolo Berto", "text": "Mayad nga agahon! Kamusta ka?", "word_id": "w001" },
		{
			"speaker": "Lolo Berto",
			"text": "Ano ing gusto ubrahon?",
			"word_id": "",
			"choices": [
				{ "label": "Gusto ko magkantigohan mag Akeanon.", "next": 2 },
				{ "label": "Wa man, saeamat.", "next": -1 },
				{ "label": "May kutana ako, lo.", "next": 3 }
			]
		},
		{ "speaker": "Lolo Berto", "text": "Mayad gid ron! Tun-i ro Akeanon.", "word_id": "w012" },
		{ "speaker": "Lolo Berto", "text": "Ano ring kutana, to?", "word_id": "" }
	]

func _on_interacted(_interactor: Node) -> void:
	print("interacted fired")
	print("dialogue lines: ", dialogue.dialogue_lines)
	dialogue.start_dialogue()
