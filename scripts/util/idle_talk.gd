# idle_talk.gd -- preload it (no class_name, same as marker_util.gd):
#   const IdleTalk := preload("res://scripts/util/idle_talk.gd")
extends RefCounted
## Generates what an NPC says once their story dialogue is finished. Each Talk
## plays one step, the next one that applies. Each NPC starts over every day
## (GameState.idle_steps):
##   GREETING  Time-of-day greeting.
##   PUZZLE    Family only, once the newspaper is reachable, while today's puzzle
##             is unsolved: reminder to solve it.
##   WORD      Word of the day and its meaning. The first time ever, each sentence
##             is also explained word by word.
##   OFFER     Offer to teach another unknown word. Declining keeps this step, so
##             it's offered again. Accepting uses up today's lesson for every NPC
##             (GameState.word_taught_date), which skips WORD and OFFER.
##   TOMORROW  A new word tomorrow. Repeats for the rest of the day.
## Returns lines in the usual dialogue format (see Comp_Dialogue.gd), plus
## "on_enter", a Callable run when the line is shown.

enum Step { GREETING, PUZZLE, WORD, OFFER, TOMORROW }

## Whose reminder this is: they live in the house with the newspaper.
const FAMILY: Array[String] = ["Lola Jonabel", "Rose", "Lola Susan", "Papa Jobert"]
## Set on arriving at the Aklan house, where the newspaper is.
const NEWSPAPER_REACHABLE_FLAG: String = "seen_chapter2_scene0"
const SENTENCES_EXPLAINED_FLAG: String = "idle_talk_sentences_explained"

const W_MAYAD: String = "w163"
const W_NGA: String = "w180"
const W_RO: String = "w202"
const W_BISAEA: String = "w254"
const W_IT: String = "w092"
const W_ADLAW: String = "w003"
const W_HAY: String = "w076"
const W_BUEOT_HAMBAEON: String = "w255"

static func build(speaker: String) -> Array:
	TutorialManager.start("idle_talk")
	var step: Step = _next_step(speaker)
	# An offer only counts as done once accepted, and that is what moves past it.
	if step != Step.OFFER:
		GameState.idle_steps[speaker] = {"date": GameState.date_unix, "step": step}
	match step:
		Step.GREETING:
			return [_line(speaker, "\\Mayad \\nga \\%s!" % TextUtil.DAY_PART_TOKEN,
					[W_MAYAD, W_NGA, TextUtil.DAY_PART_TOKEN])]
		Step.PUZZLE:
			return [_line(speaker, "Remember to solve the newspaper puzzle.")]
		Step.WORD:
			var explain: bool = not GameState.get_flag(SENTENCES_EXPLAINED_FLAG)
			return _word_lines(speaker, WordBank.get_word_of_the_day(), explain)
		Step.OFFER:
			return _offer_lines(speaker)
	return [_line(speaker, "We'll teach you a new word tomorrow.")]

## The first step after the last one this NPC played today that applies now.
static func _next_step(speaker: String) -> Step:
	var progress: Dictionary = GameState.idle_steps.get(speaker, {})
	if progress.get("date", 0) != GameState.date_unix:
		return Step.GREETING
	var step: int = int(progress.get("step", Step.GREETING)) + 1
	while step < Step.TOMORROW and not _applies(step, speaker):
		step += 1
	return mini(step, Step.TOMORROW) as Step

static func _applies(step: int, speaker: String) -> bool:
	match step:
		Step.PUZZLE:
			return FAMILY.has(speaker) and GameState.get_flag(NEWSPAPER_REACHABLE_FLAG) \
					and not GameState.is_puzzle_solved_today()
		Step.WORD:
			return not GameState.is_word_taught_today()
		Step.OFFER:
			return not GameState.is_word_taught_today() and not _lesson_words().is_empty()
	return true

## Unknown words to teach, leaving today's word to the newspaper and WORD.
static func _lesson_words() -> Array:
	var unknown: Array = WordBank.get_unknown_word_ids()
	unknown.erase(WordBank.get_word_of_the_day())
	return unknown

static func _offer_lines(speaker: String) -> Array:
	TutorialManager.start("word_lesson")
	var word_id: String = _lesson_words().pick_random()
	var offer: Dictionary = _line(speaker, "Do you want to learn another word?")
	offer["choices"] = [
		{"label": "Yes, teach me!", "next": 1},
		{"label": "Maybe later."},
	]
	var lesson: Array = _word_lines(speaker, word_id, false)
	lesson[0]["on_enter"] = _on_lesson_started.bind(speaker)
	return [offer] + lesson

static func _on_lesson_started(speaker: String) -> void:
	GameState.mark_word_taught()
	GameState.idle_steps[speaker] = {"date": GameState.date_unix, "step": Step.OFFER}

## "The word of the day is X. The meaning is Y.", with explain, each followed by
## what it means.
static func _word_lines(speaker: String, word_id: String, explain: bool) -> Array:
	var form: String = WordBank.clean_form(WordBank.get_word(word_id).get("akeanon", ""))
	var gloss: String = WordBank.get_word(word_id).get("gloss", "")
	var lines: Array = [_line(speaker, "\\Ro \\bisaea \\it \\adlaw \\hay \\%s." % form,
			[W_RO, W_BISAEA, W_IT, W_ADLAW, W_HAY, word_id])]
	if explain:
		var word_part: Dictionary = _line(speaker,
				"That means \"the word of the day is %s\". \\Ro is \"the\", \\bisaea is \"word\", \\it is \"of\", \\adlaw is \"day\" and \\hay is \"is\"." % form)
		word_part["set_flag_on_enter"] = SENTENCES_EXPLAINED_FLAG
		lines.append(word_part)
	if gloss.is_empty():
		return lines
	lines.append(_line(speaker, "\\Nga \\ro \\bueot-hambaeon \\hay %s." % gloss,
			[W_NGA, W_RO, W_BUEOT_HAMBAEON, W_HAY]))
	if explain:
		lines.append(_line(speaker,
				"That means \"that the meaning is %s\". \\Nga is \"that\" and \\bueot-hambaeon is \"meaning\"." % gloss))
	return lines

static func _line(speaker: String, text: String, word_ids: Array = []) -> Dictionary:
	return {"speaker": speaker, "text": text, "word_ids": word_ids, "type": "dialogue"}
