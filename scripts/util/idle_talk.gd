# idle_talk.gd -- preload it (no class_name, same as marker_util.gd):
#   const IdleTalk := preload("res://scripts/util/idle_talk.gd")
extends RefCounted
## Generates what an NPC says once their story dialogue is finished. Each Talk
## plays one step, the next one that applies. Each NPC starts over every day
## (GameState.idle_steps):
##   GREETING  Time-of-day greeting.
##   AMBIENT   One sentence for where they are, the time of day and the weekday
##             (data/idle_ambient.json), when one fits.
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
##
## Before all of that, a pending STORY REMARK plays instead: a one-time reaction
## to something that happened in the story (Jonabel and the piña bookmark).
## Authored per chapter under "remarks" in data/dialogue/<chapter>.json:
##   "remarks": {"jonabel_bookmark_kept": {"speaker": "Lola Jonabel",
##       "requires": ["got_pina_bookmark"], "unless": [...], "lines": [ ... ]}}
## A remark is pending while every "requires" flag is set, no "unless" flag is,
## and its seen flag ("remark_<id>_seen") isn't. One per talk, newest chapter
## first, then in authored order; the rest wait for later talks.

enum Step { GREETING, AMBIENT, PUZZLE, WORD, OFFER, TOMORROW }

## Location, time and weekday sentences for the AMBIENT step. Entries with
## "draft": true are skipped until their Akeanon is reviewed.
const AMBIENT_PATH: String = "res://data/idle_ambient.json"
## Weekday name tokens, index 0 = Sunday (Time.get_date_dict weekday).
const WEEKDAY_TOKEN: String = "[Weekday]"
const WEEKDAYS: Array = [["Domingo", "w318"], ["Lunes", "w312"], ["Martes", "w313"], ["Miyerkoles", "w314"], ["Hwebes", "w315"], ["Biyernes", "w316"], ["Sabado", "w317"]]
static var _ambient_cache: Array = []
static var _ambient_loaded: bool = false

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

## Chapters searched for remarks, newest first.
const REMARK_CHAPTERS: Array[String] = ["chapter6", "chapter5", "chapter4", "chapter3", "chapter2", "chapter1"]

static func build(speaker: String) -> Array:
	var remark: Array = _remark_lines(speaker)
	if not remark.is_empty():
		return remark
	TutorialManager.start("idle_talk")
	var step: Step = _next_step(speaker)
	# An offer only counts as done once accepted, and that is what moves past it.
	if step != Step.OFFER:
		GameState.idle_steps[speaker] = {"date": GameState.daily_date(), "step": step}
	match step:
		Step.GREETING:
			return [_line(speaker, "\\Mayad \\nga \\%s!" % TextUtil.DAY_PART_TOKEN,
					[W_MAYAD, W_NGA, TextUtil.DAY_PART_TOKEN])]
		Step.AMBIENT:
			return _ambient_lines(speaker, _ambient_matches(speaker).pick_random())
		Step.PUZZLE:
			return [_line(speaker, "Remember to solve the newspaper puzzle.")]
		Step.WORD:
			var explain: bool = not GameState.get_flag(SENTENCES_EXPLAINED_FLAG)
			return _word_lines(speaker, WordBank.get_word_of_the_day(), explain)
		Step.OFFER:
			return _offer_lines(speaker)
	return [_line(speaker, "We'll teach you a new word tomorrow.")]

## Lines of the first pending story remark for this speaker, or []. Marks it
## seen as its first line shows, so closing the box early still counts.
static func _remark_lines(speaker: String) -> Array:
	for chapter_id: String in REMARK_CHAPTERS:
		var remarks: Dictionary = ChapterLoader.get_remarks(chapter_id)
		for remark_id: String in remarks:
			var remark: Dictionary = remarks[remark_id]
			if str(remark.get("speaker", "")) != speaker or not remark_pending(remark_id, remark):
				continue
			var lines: Array = remark.get("lines", []).duplicate(true)
			if lines.is_empty():
				continue
			lines[0]["on_enter"] = GameState.set_flag.bind(remark_seen_flag(remark_id), true)
			return lines
	return []

static func remark_pending(remark_id: String, remark: Dictionary) -> bool:
	if GameState.get_flag(remark_seen_flag(remark_id)):
		return false
	for flag in remark.get("requires", []):
		if not GameState.get_flag(str(flag)):
			return false
	for flag in remark.get("unless", []):
		if GameState.get_flag(str(flag)):
			return false
	return true

static func remark_seen_flag(remark_id: String) -> String:
	return "remark_%s_seen" % remark_id

## The first step after the last one this NPC played today that applies now.
static func _next_step(speaker: String) -> Step:
	var progress: Dictionary = GameState.idle_steps.get(speaker, {})
	if progress.get("date", 0) != GameState.daily_date():
		return Step.GREETING
	var step: int = int(progress.get("step", Step.GREETING)) + 1
	while step < Step.TOMORROW and not _applies(step, speaker):
		step += 1
	return mini(step, Step.TOMORROW) as Step

static func _applies(step: int, speaker: String) -> bool:
	match step:
		Step.AMBIENT:
			return not _ambient_matches(speaker).is_empty()
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
	GameState.idle_steps[speaker] = {"date": GameState.daily_date(), "step": Step.OFFER}

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

## Reviewed ambient templates that fit the current area, day part, weekday and
## speaker. Template fields (all but text optional):
##   areas    GameState.current_area ids; empty = anywhere
##   parts    "morning" / "afternoon" / "night" (TextUtil hours); empty = any time
##   weekdays 0 = Sunday … 6 = Saturday; empty = any day
##   speakers npc ids, "family" (FAMILY) or "stranger" (anyone else); empty = anyone
##   ask      optional line the PLAYER says first (asking directions)
##   text, translation, word_ids  as in dialogue lines; [Weekday] and [DayPart]
##            tokens are filled in, and listed in word_ids to tag them
static func _ambient_matches(speaker: String) -> Array:
	var part: String = _day_part_key()
	var weekday: int = int(DayNightManager.get_date()["weekday"])
	var out: Array = []
	for t: Dictionary in _ambient_templates():
		if t.get("draft", false):
			continue
		var areas: Array = t.get("areas", [])
		if not areas.is_empty() and not areas.has(GameState.current_area):
			continue
		var parts: Array = t.get("parts", [])
		if not parts.is_empty() and not parts.has(part):
			continue
		var days: Array = t.get("weekdays", [])
		if not days.is_empty() and not days.any(func(d): return int(d) == weekday):
			continue
		var who: Array = t.get("speakers", [])
		if not who.is_empty() and not who.has(speaker) and not (who.has("family") and FAMILY.has(speaker)) \
				and not (who.has("stranger") and not FAMILY.has(speaker)):
			continue
		out.append(t)
	return out

static func _ambient_line(speaker: String, t: Dictionary) -> Dictionary:
	var day: Array = WEEKDAYS[int(DayNightManager.get_date()["weekday"])]
	var ids: Array = []
	for id in t.get("word_ids", []):
		ids.append(day[1] if str(id) == WEEKDAY_TOKEN else str(id))
	var line: Dictionary = _line(speaker, str(t.get("text", "")).replace(WEEKDAY_TOKEN, day[0]), ids)
	var translation: String = str(t.get("translation", "")).replace(WEEKDAY_TOKEN, day[0])
	if not translation.is_empty():
		line["translation"] = TextUtil.resolve_day_part(translation)
	return line

## One line, or for "kind": "weekday_quiz" the question with three weekday
## choices (today's plus two others, shuffled) and the right/wrong reply.
## A right answer is a correct use of that weekday word: +1 mastery.
static func _ambient_lines(speaker: String, t: Dictionary) -> Array:
	var question: Dictionary = _ambient_line(speaker, t)
	if t.get("kind", "") == "pick":
		# Any answer leads to the same reply.
		question["choices"] = t.get("choices", []).map(func(label): return {"label": str(label), "next": 1})
		var reply: Dictionary = _ambient_line(speaker, t.get("reply", {}))
		reply["next"] = null
		return [question, reply]
	if t.get("kind", "") != "weekday_quiz":
		if t.has("ask"):
			return [_ambient_line("Player", t["ask"]), question]
		return [question]
	var today: int = int(DayNightManager.get_date()["weekday"])
	var options: Array = [today]
	var others: Array = range(WEEKDAYS.size()).filter(func(d): return d != today)
	others.shuffle()
	options.append_array(others.slice(0, 2))
	options.shuffle()
	var choices: Array = []
	for d in options:
		choices.append({"label": WEEKDAYS[d][0], "next": 1 if d == today else 2})
	question["choices"] = choices
	var right: Dictionary = _ambient_line(speaker, t.get("right", {}))
	right["next"] = null
	right["on_enter"] = GameState.adjust_mastery.bind(WEEKDAYS[today][1], 1)
	var wrong: Dictionary = _ambient_line(speaker, t.get("wrong", {}))
	wrong["next"] = null
	return [question, right, wrong]

static func _ambient_templates() -> Array:
	if not _ambient_loaded:
		_ambient_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AMBIENT_PATH))
		if parsed is Dictionary and parsed.get("templates", null) is Array:
			_ambient_cache = parsed["templates"]
		else:
			push_error("IdleTalk: bad or missing %s" % AMBIENT_PATH)
	return _ambient_cache

static func _day_part_key() -> String:
	var hour: float = DayNightManager.get_hour()
	if hour >= TextUtil.MORNING_START and hour < TextUtil.AFTERNOON_START:
		return "morning"
	if hour >= TextUtil.AFTERNOON_START and hour < TextUtil.NIGHT_START:
		return "afternoon"
	return "night"
