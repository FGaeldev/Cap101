# DialogueComponent — attach to NPC; drives dialogue system
class_name DialogueComponent
extends Node

## dialogue_lines: Array of Dictionaries
## Each line: { "speaker": "Elder", "text": "Maayong aga!", "word_id": "w001" }
@export var dialogue_lines: Array = []
@export var npc_id: String = ""

var _current_line: int = 0

func start_dialogue() -> void:
	_current_line = 0
	_show_line()

func advance() -> void:
	_current_line += 1
	if _current_line >= dialogue_lines.size():
		_end()
		return
	_show_line()

func _show_line() -> void:
	var line: Dictionary = dialogue_lines[_current_line]
	# Expose word if line has one
	if line.has("word_id") and not line["word_id"].is_empty():
		GameState.expose_word(line["word_id"])
		# Auto-add to notes if first encounter
		if GameState.get_exposure(line["word_id"]) == 1:
			GameState.save_note(line["word_id"], "") # blank — player fills
	# Send to DialogueUI singleton/signal
	DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self)

func _end() -> void:
	DialogueUI.hide()
	# Check if this NPC's quest is completable
	QuestManager.complete_quest(QuestManager.active_quest)
