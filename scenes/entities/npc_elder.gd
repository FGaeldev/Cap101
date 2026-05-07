# NPC_Elder.gd
extends CharacterBody2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)
	dialogue.npc_id = "npc_elder"
	dialogue.dialogue_lines = [
		{ "speaker": "Lolo Berto", "text": "Maayong aga! Kamusta ka?", "word_id": "w001" },
		{
			"speaker": "Lolo Berto",
			"text": "Ano ang buot mo himuon subong?",
			"word_id": "",
			"choices": [
				{ "label": "Gusto ko makahibalo sang Akeanon.", "next": 2 },
				{ "label": "Wala lang, salamat.", "next": -1 },
				{ "label": "May pamangkot ako.", "next": 3 }
			]
		},
		{ "speaker": "Lolo Berto", "text": "Maayo gid ina! Tun-i ang Akeanon.", "word_id": "w012" },
		{ "speaker": "Lolo Berto", "text": "Ano ang imo pamangkot, anak?", "word_id": "" }
	]

func _on_interacted(_interactor: Node) -> void:
	print("interacted fired")
	print("dialogue lines: ", dialogue.dialogue_lines)
	dialogue.start_dialogue()
