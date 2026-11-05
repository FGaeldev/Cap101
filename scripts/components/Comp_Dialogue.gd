# DialogueComponent.gd — supports linear + branching dialogue
class_name DialogueComponent
extends Node

const IdleTalk := preload("res://scripts/util/idle_talk.gd")

@export var npc_id: String = ""
@export var dialogue_lines: Array = []
@export var completes_quest_id: String = ""   # empty = ambient dialogue, no quest side-effect

var _current_line: int = 0
var _last_speaker: String = ""   # most recent non-blank speaker; choice deltas attribute to this NPC
var _pending_gate_id: String = ""   # challenge_id this component is currently waiting on, "" if none
var _pending_gate_next = null       # next_on_pass to jump to once _pending_gate_id passes

## Emitted once dialogue reaches its end (linear falls off the end, a choice
## resolves to no next, or a challenge_gate's _end() path fires). Callers use
## this to detect "story dialogue for this NPC/scene is now exhausted" and
## switch subsequent interacts to start_idle_dialogue() instead — see
## TDD_Addendum_ProfFeedback.md §2. Fires for idle dialogue too (harmless,
## callers guard with their own already-set flag check).
signal dialogue_ended

func start_dialogue() -> void:
	_current_line = 0
	_last_speaker = ""
	if dialogue_lines.is_empty():
		_end()
		return
	# Resolve any non-display routing lines before showing dialogue.
	_resolve_start_router()
	if _current_line >= dialogue_lines.size():
		_end()
		return
	_show_line()

func _resolve_start_router() -> void:
	var safety := 0

	while _current_line < dialogue_lines.size():
		var line: Dictionary = dialogue_lines[_current_line]

		if line.get("type", "") != "start_router":
			return

		var routes: Dictionary = line.get("start_index_if_flag", {})
		var next_index: int = routes.get("default", _current_line + 1)

		for flag_id in routes:
			if flag_id == "default":
				continue

			if GameState.get_flag(flag_id):
				next_index = routes[flag_id]
				break

		# Prevent malformed dialogue data from looping forever.
		if next_index == _current_line:
			push_error(
				"Dialogue start_router points to itself at index %d" % _current_line
			)
			_end()
			return

		_current_line = next_index

		safety += 1
		if safety > 100:
			push_error("Dialogue start_router exceeded 100 redirects.")
			_end()
			return

## What an NPC says once their story is done, generated fresh each time (IdleTalk).
func start_idle_dialogue() -> void:
	dialogue_lines = IdleTalk.build(npc_id)
	start_dialogue()

func advance() -> void:
	# Only called for non-choice lines.
	AudioManager.play_sfx("advance")
	TutorialManager.notify("dialogue_advanced")
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

## Resolves the next line index. check_flag wins first: if the named flag is
## set, jump to "check_flag_next". Then patience_branch:
## [{"min_patience": int, "next": int}, ...] — evaluates against
## the last-speaking NPC's current patience (read-only, reflects prior choices),
## picks the highest min_patience threshold met. Falls back to explicit "next",
## else sequential fallthrough.
func _resolve_next(line: Dictionary):
	var check_id := str(line.get("check_flag", "")).strip_edges()
	if not check_id.is_empty() and line.has("check_flag_next") and GameState.get_flag(check_id):
		return line["check_flag_next"]
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

	if line.get("type", "") == "challenge_gate":
		_handle_challenge_gate(line)
		return

	if line.get("type", "") == "phrase_builder":
		_handle_phrase_builder(line)
		return

	if line.get("type", "") == "quiz":
		_handle_quiz(line)
		return

	if line.get("type", "") == "minigame_trigger":
		_handle_minigame(line)
		return

	if line.has("on_enter"):
		line["on_enter"].call()
	# Apply authored story flags when this line becomes active.
	var flag_id := str(line.get("set_flag_on_enter", "")).strip_edges()
	if not flag_id.is_empty():
		GameState.set_flag(flag_id)
	# set_flag: {"flag": id, "value": bool} -- like set_flag_on_enter, but can
	# also clear a flag. A bare string is shorthand for value true.
	var set_spec = line.get("set_flag", null)
	if set_spec is Dictionary:
		var set_id := str(set_spec.get("flag", "")).strip_edges()
		if not set_id.is_empty():
			GameState.set_flag(set_id, bool(set_spec.get("value", true)))
	elif set_spec is String and not set_spec.strip_edges().is_empty():
		GameState.set_flag(set_spec.strip_edges())

	var portrait_tex = CharacterRegistry.get_portrait(
		line.get("speaker", "")
	)

	# Word exposure
	if line.has("word_ids"):
		for wid in line["word_ids"]:
			var word_id := TextUtil.resolve_word_id(str(wid).strip_edges())
			if word_id.is_empty():
				continue
			if WordBank.get_word(word_id).is_empty():
				push_warning("Dialogue references unknown word ID '%s'." % word_id)
				continue
			GameState.expose_word(word_id)

	var speaker: String = line.get("speaker", "")

	if not speaker.is_empty():
		_last_speaker = speaker

	if line.has("choices") and not line["choices"].is_empty():
		DialogueUI.show_line(
			line.get("speaker", ""),
			line.get("text", ""),
			self,
			portrait_tex
		)
		DialogueUI.show_choices(line["choices"], self)
	else:
		DialogueUI.show_line(
			line.get("speaker", ""),
			line.get("text", ""),
			self,
			portrait_tex
		)

## phrase_builder line: suspend normal line display, hand the line to the UI.
## Player stays input-locked because DialogueUI._current_component stays set.
func _handle_phrase_builder(line: Dictionary) -> void:
	DialogueUI.hide_box_only()
	DialogueUI.show_phrase_builder(TextUtil.resolve_builder_line(line), self)

## Called by DialogueUI when the builder resolves. Jumps to the line's
## "success" / "failure" index, falling back to "next", else ends dialogue.
func resolve_phrase_builder(passed: bool) -> void:
	var line: Dictionary = dialogue_lines[_current_line]
	var nxt = line.get("success" if passed else "failure", line.get("next"))
	if nxt == null or nxt >= dialogue_lines.size():
		_end()
		return
	_current_line = nxt
	_show_line()

## quiz line: suspend normal line display, hand the line to the quiz panel.
## Player stays input-locked because DialogueUI._current_component stays set.
func _handle_quiz(line: Dictionary) -> void:
	DialogueUI.hide_box_only()
	DialogueUI.show_quiz(line, self)

## Called by DialogueUI when the quiz resolves. Jumps to the line's
## "success" / "failure" index, falling back to "next", else ends dialogue.
func resolve_quiz(passed: bool) -> void:
	var line: Dictionary = dialogue_lines[_current_line]
	var nxt = line.get("success" if passed else "failure", line.get("next"))
	if nxt == null or nxt >= dialogue_lines.size():
		_end()
		return
	_current_line = nxt
	_show_line()

## minigame_trigger line: suspend normal line display, hand the line to the
## minigame panel for line["minigame_type"].
func _handle_minigame(line: Dictionary) -> void:
	DialogueUI.hide_box_only()
	DialogueUI.show_minigame(line, self)

## Called by DialogueUI when the minigame resolves. Jumps to the line's
## "success" / "failure" index, falling back to "next", else ends dialogue.
func resolve_minigame(passed: bool) -> void:
	var line: Dictionary = dialogue_lines[_current_line]
	var nxt = line.get("success" if passed else "failure", line.get("next"))
	if nxt == null or nxt >= dialogue_lines.size():
		_end()
		return
	_current_line = nxt
	_show_line()

func _end() -> void:
	DialogueUI.hide()
	if not completes_quest_id.is_empty():
		QuestManager.complete_quest(completes_quest_id)
	dialogue_ended.emit()

## Entry point for a challenge_gate line. No fallback "next" — this is a
## wait-state, not a branch (TDD §5). Puzzle UI presentation for the
## challenge itself is out of scope here; DialogueUI.challenge_gate_entered
## is the hook point for whatever owns puzzle_panel to react to (Roadmap
## Phase A "puzzle_panel.gd wiring" item, tracked separately).
func _handle_challenge_gate(line: Dictionary) -> void:
	var challenge_id: String = line.get("challenge_id", "")
	var next_on_pass = line.get("next_on_pass", null)

	if ChallengeManager.is_passed(challenge_id):
		_advance_past_gate(next_on_pass)
		return

	DialogueUI.hide_box_only()
	DialogueUI.challenge_gate_entered.emit(challenge_id)

	_pending_gate_id = challenge_id
	_pending_gate_next = next_on_pass
	if not ChallengeManager.challenge_passed.is_connected(_on_challenge_passed):
		ChallengeManager.challenge_passed.connect(_on_challenge_passed)

## Filters ChallengeManager's global challenge_passed signal down to the
## single gate this component is currently suspended on. Persistent
## connection guard (not CONNECT_ONE_SHOT) because a challenge_passed signal
## for a DIFFERENT challenge_id must not consume this component's wait.
func _on_challenge_passed(challenge_id: String, _first_try: bool) -> void:
	if challenge_id != _pending_gate_id:
		return
	ChallengeManager.challenge_passed.disconnect(_on_challenge_passed)
	_pending_gate_id = ""
	_advance_past_gate(_pending_gate_next)

func _advance_past_gate(next_on_pass) -> void:
	if next_on_pass == null or next_on_pass >= dialogue_lines.size():
		_end()
		return
	_current_line = next_on_pass
	_show_line()

## Cleanup guard: if this component's scene is torn down while suspended on
## a challenge_gate (e.g. player quits mid-gate), the connection to
## ChallengeManager.challenge_passed must not dangle.
func _exit_tree() -> void:
	if ChallengeManager.challenge_passed.is_connected(_on_challenge_passed):
		ChallengeManager.challenge_passed.disconnect(_on_challenge_passed)
