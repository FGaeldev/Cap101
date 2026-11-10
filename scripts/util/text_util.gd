class_name TextUtil
extends RefCounted
## Stateless display-text resolver for dialogue/UI strings.
## Same pattern as DirectionUtil: static helper, no autoload registration.
## Single choke point so token rules never drift between systems.
##
## Authoring rules (data/*.json):
##   "[Player]"  -> replaced with GameState.player_name
##   "\word"     -> marks an Akeanon word; the "\" is stripped at render time
##   "[DayPart]" -> agahon / hapon / gabie for the in-game time, for greetings
##                  (also a phrase builder word; in word_ids, its word's id)
##   "[GoodDay]" -> Good morning / Good afternoon / Good evening
##   "[good day]" -> the same in lower case
## JSON files must escape the backslash: write "\\Mayad", parser yields "\Mayad".
##
## Data is NEVER mutated. Call at render time only, after word_ids / next /
## branching logic has already consumed the raw line.

const PLAYER_TOKEN: String = "[Player]"
## Shown when player_name is empty (old saves, skipped name entry).
const FALLBACK_NAME: String = "Traveler"
## Speaker id used in dialogue data for the protagonist.
const PLAYER_SPEAKER_ID: String = "Player"
## Single backslash character (GDScript escape).
const AKEANON_MARKER: String = "\\"
## A marker and the word after it. Hyphens and apostrophes stay in the word.
const MARKED_WORD_PATTERN: String = "\\\\([\\p{L}\\p{M}0-9'’-]+)"
static var _marked_word: RegEx
## Longest name accepted by name entry.
const MAX_NAME_LENGTH: int = 12
const DAY_PART_TOKEN: String = "[DayPart]"
const GOOD_DAY_TOKEN: String = "[GoodDay]"
const GOOD_DAY_LOWER_TOKEN: String = "[good day]"
## Morning runs from this hour up to AFTERNOON_START.
const MORNING_START: float = 6.0
const AFTERNOON_START: float = 12.0
## "Gabie" from this hour until the next MORNING_START.
const NIGHT_START: float = 18.0
const DAY_PARTS: Dictionary = {
	"morning": {"word": "agahon", "word_id": "w006", "english": "Good morning"},
	"afternoon": {"word": "hapon", "word_id": "w253", "english": "Good afternoon"},
	"night": {"word": "gabie", "word_id": "w252", "english": "Good evening"},
}

## Entry of DAY_PARTS for the current in-game hour.
static func current_day_part() -> Dictionary:
	var hour: float = DayNightManager.get_hour()
	if hour >= MORNING_START and hour < AFTERNOON_START:
		return DAY_PARTS["morning"]
	if hour >= AFTERNOON_START and hour < NIGHT_START:
		return DAY_PARTS["afternoon"]
	return DAY_PARTS["night"]

## Word id for a line's word_ids entry, swapping in the current day part's.
static func resolve_word_id(word_id: String) -> String:
	return current_day_part()["word_id"] if word_id == DAY_PART_TOKEN else word_id

## Copy of a phrase_builder line with day part tokens filled in. Its tiles are
## compared as strings, so they have to be real words before the panel sees them.
static func resolve_builder_line(line: Dictionary) -> Dictionary:
	var out: Dictionary = line.duplicate(true)
	out["prompt"] = resolve_day_part(str(out.get("prompt", "")))
	for key: String in ["choices", "answer"]:
		var words: Array = out.get(key, [])
		for i in words.size():
			words[i] = resolve_day_part(str(words[i]))
	return out

static func resolve_day_part(raw: String) -> String:
	var part: Dictionary = current_day_part()
	var english: String = part["english"]
	return raw.replace(DAY_PART_TOKEN, part["word"]) \
			.replace(GOOD_DAY_TOKEN, english) \
			.replace(GOOD_DAY_LOWER_TOKEN, english.to_lower())


## Returns `raw` with the player token substituted and Akeanon markers removed.
static func resolve(raw: String) -> String:
	return _fill_tokens(raw).replace(AKEANON_MARKER, "")


## BBCode version of resolve() for RichTextLabel: each marked word gets the
## Akeanon color and an underline.
static func resolve_rich(raw: String) -> String:
	if _marked_word == null:
		_marked_word = RegEx.create_from_string(MARKED_WORD_PATTERN)
	var open: String = "[color=#%s][u]" % Accessibility.akeanon_color().to_html(false)
	var close: String = "[/u][/color]"
	var escaped: String = _fill_tokens(raw).replace("[", "[lb]")
	return _marked_word.sub(escaped, open + "$1" + close, true).replace(AKEANON_MARKER, "")


static func _fill_tokens(raw: String) -> String:
	var name_out: String = GameState.player_name.strip_edges()
	if name_out.is_empty():
		name_out = FALLBACK_NAME
	return resolve_day_part(raw).replace(PLAYER_TOKEN, name_out)


## Resolves a speaker id for display. Data uses the literal speaker id
## "Player" for the protagonist; shows the chosen name instead. Other speakers
## pass through resolve() so tokens/markers still work. Portrait lookup and
## rapport attribution keep using the RAW id -- call this at render only.
static func resolve_speaker(raw: String) -> String:
	if raw == PLAYER_SPEAKER_ID:
		return resolve(PLAYER_TOKEN)
	return resolve(raw)


## Cleans raw player input into a safe display name: trims, drops characters
## that collide with the token/marker syntax ("\", "[", "]"), caps length.
static func sanitize_name(raw: String) -> String:
	var cleaned: String = raw.replace(AKEANON_MARKER, "").replace("[", "").replace("]", "")
	cleaned = cleaned.strip_edges()
	return cleaned.left(MAX_NAME_LENGTH)
