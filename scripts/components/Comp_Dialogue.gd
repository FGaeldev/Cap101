# DialogueComponent.gd — supports linear + branching dialogue
class_name DialogueComponent
extends Node

@export var npc_id: String = ""
@export var dialogue_lines: Array = []
@export var completes_quest_id: String = ""   # empty = ambient dialogue, no quest side-effect

var _current_line: int = 0
var _last_speaker: String = ""   # most recent non-blank speaker; choice deltas attribute to this NPC

func start_dialogue() -> void:
	_current_line = 0
	_last_speaker = ""
	_show_line()

func advance() -> void:
	# Only called for non-choice lines.
	AudioManager.play_sfx("advance")
	var line: Dictionary = dialogue_lines[_current_line]
	var nxt = _resolve_next(line)
	if nxt == null:
		_end()
		return
	_current_line = nxt
	if _current_line >= dialogue_lines.size():
		_end()
		return
	_show_line()

## Resolves the next line index, honoring patience_branch if present.
## patience_branch: [{"min_patience": int, "next": int}, ...] — evaluates against
## the last-speaking NPC's current patience (read-only, reflects prior choices),
## picks the highest min_patience threshold met. Falls back to explicit "next",
## else sequential fallthrough.
func _resolve_next(line: Dictionary):
	if line.has("patience_branch") and not _last_speaker.is_empty():
		var current_patience: int = GameState.get_patience(_last_speaker)
		var best_next = null
		var best_min: int = -1
		for branch in line["patience_branch"]:
			var min_p: int = branch.get("min_patience", 0)
			if current_patience >= min_p and min_p > best_min:
				best_min = min_p
				best_next = branch.get("next")
		if best_next != null:
			return best_next
	return line.get("next", _current_line + 1)

## Called by ChoiceUI when player picks an option. Takes the full choice dict
## (not just the next index) so rapport_delta/patience_delta on the CHOICE
## itself — the only place player agency actually enters — can be applied.
## Attributed to _last_speaker: the NPC the player was just responding to.
func choose(choice: Dictionary) -> void:
	if not _last_speaker.is_empty():
		if choice.has("rapport_delta"):
			GameState.adjust_rapport(_last_speaker, choice["rapport_delta"])
		if choice.has("patience_delta"):
			GameState.adjust_patience(_last_speaker, choice["patience_delta"])

	var next_index = choice.get("next", -1)
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

	var speaker: String = line.get("speaker", "")
	if not speaker.is_empty():
		_last_speaker = speaker   # tracked for choice-delta attribution + patience_branch reads

	# Branch or linear
	if line.has("choices") and not line["choices"].is_empty():
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self, portrait_tex)
		DialogueUI.show_choices(line["choices"], self)
	else:
		DialogueUI.show_line(line.get("speaker",""), line.get("text",""), self, portrait_tex)

func _end() -> void:
	DialogueUI.hide()
	if not completes_quest_id.is_empty():
		QuestManager.complete_quest(completes_quest_id)
