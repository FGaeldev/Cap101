# DialogueComponent.gd — supports linear + branching dialogue
class_name DialogueComponent
extends Node

@export var npc_id: String = ""
@export var dialogue_lines: Array = []
@export var completes_quest_id: String = ""   # empty = ambient dialogue, no quest side-effect

var _current_line: int = 0
var _last_speaker: String = ""   # most recent non-blank speaker; choice deltas attribute to this NPC
var _pending_gate_id: String = ""   # challenge_id this component is currently waiting on, "" if none
var _pending_gate_next = null       # next_on_pass to jump to once _pending_gate_id passes
var _idle_bag: Array = []           # shuffle-bag of remaining indices into the last idle pool passed in

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
	_show_line()

## Idle/ambient line, drawn from an NPC's idle pool via shuffle-bag
## (draw-without-replacement, reshuffle when exhausted) so repeat visits
## don't repeat the same line back to back. Idle lines are leaf nodes -- no
## choices, no "next" -- so this reuses the normal single-line dialogue
## path unchanged (TDD_Addendum_ProfFeedback.md §2). Caller passes the pool
## fresh each call (ChapterLoader.get_idle_pool); bag state persists on this
## component instance across calls within the same play session.
func start_idle_dialogue(pool: Array) -> void:
	if pool.is_empty():
		return
	if _idle_bag.is_empty():
		_refill_idle_bag(pool.size())
	var idx: int = _idle_bag.pop_back()
	dialogue_lines = [pool[idx]]
	start_dialogue()

func _refill_idle_bag(size: int) -> void:
	_idle_bag.clear()
	for i in range(size):
		_idle_bag.append(i)
	_idle_bag.shuffle()

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

	# challenge_gate (TDD §5): wait-state, not a branch. No text/choices are
	# shown for this line type — it either passes through immediately (already
	# passed) or suspends dialogue until ChallengeManager reports a pass.
	if line.get("type", "") == "challenge_gate":
		_handle_challenge_gate(line)
		return

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
