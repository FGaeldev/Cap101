# DialogueComponent.gd — supports linear + branching dialogue
class_name DialogueComponent
extends Node

signal word_revealed(word_id: String, akeanon: String)

@export var dialogue_lines: Array = []
@export var npc_id: String = ""

var _current_line: int = 0

func start_dialogue() -> void:
	_current_line = 0
	_show_line()

func advance() -> void:
	# Only called for non-choice lines
	_current_line += 1
	if _current_line >= dialogue_lines.size():
		_end()
		return
	_show_line()

func choose(next_index: int) -> void:
	# Called by ChoiceUI when player picks option
	if next_index == -1:
		_end()
		return
	_current_line = next_index
	if _current_line >= dialogue_lines.size():
		_end()
		return
	_show_line()

func _show_line() -> void:
	var line: Dictionary = dialogue_lines[_current_line]

	# Word exposure
	if line.has("word_id") and not line["word_id"].is_empty():
		var wid = line["word_id"]
		var is_new = not GameState.player_notes.has(wid)
		GameState.expose_word(wid)
		if not GameState.player_notes.has(wid):
			GameState.save_note(wid, "")
		if is_new:
			var word_data = WordBank.get_word(wid)
			word_revealed.emit(wid, word_data.get("akeanon", ""))

	# Branch or linear
	if line.has("choices") and not line["choices"].is_empty():
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self)
		DialogueUI.show_choices(line["choices"], self)
	else:
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self)

func _end() -> void:
	DialogueUI.hide()
	QuestManager.complete_quest(QuestManager.active_quest)
