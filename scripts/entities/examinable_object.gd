# examinable_object.gd — world object that triggers a fill-in-blank puzzle
extends StaticBody2D

@onready var interactable: InteractableComponent = $InteractableComponent

## Set these in inspector per object instance
@export var object_id: String = "obj001"
@export var quest_flag: String = ""        # flag set on puzzle solve
@export var sentence_template: String = "Ang ___ ay mahalaga sa buhay."
@export var answer_word_id: String = "w007"
@export var distractor_ids: Array = ["w001", "w004"]
@export var already_solved_dialogue: String = "Nasulbad na nimo ini."

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	print("tapped")
	
	# Already solved — just show short message
	if quest_flag != "" and GameState.get_flag(quest_flag):
		DialogueUI.show_line("", already_solved_dialogue, null)
		return

	# Open puzzle
	var puzzle = get_tree().get_first_node_in_group("puzzle_panel")
	if puzzle:
		print("puzzel")
		puzzle.open_single(
			sentence_template,
			answer_word_id,
			distractor_ids,
			_on_puzzle_solved
		)

func _on_puzzle_solved() -> void:
	if quest_flag != "":
		GameState.set_flag(quest_flag)
		GameState.save_game()
	QuestManager.complete_quest(QuestManager.active_quest)
