# DialogueComponent.gd — supports linear + branching dialogue
class_name DialogueComponent
extends Node

@export var dialogue_lines: Array = []
@export var npc_id: String = ""

var _current_line: int = 0

func start_dialogue() -> void:
	_current_line = 0
	_show_line()

func advance() -> void:
	# Only called for non-choice lines.
	var line: Dictionary = dialogue_lines[_current_line]
	var nxt = line.get("next", _current_line + 1)  # explicit next, else fall through sequentially
	if nxt == null:
		_end()
		return
	_current_line = nxt
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
	var portrait_tex = CharacterRegistry.get_portrait(line.get("speaker", ""))
	
	# Word exposure (Dictionary unlock)
	if line.has("word_ids"):
		for wid in line["word_ids"]:
			if not wid.is_empty():
				GameState.expose_word(wid)

	# Branch or linear
	if line.has("choices") and not line["choices"].is_empty():
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self, portrait_tex)
		DialogueUI.show_choices(line["choices"], self)
	else:
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self, portrait_tex)

func _end() -> void:
	DialogueUI.hide()
	QuestManager.complete_quest(QuestManager.active_quest)
