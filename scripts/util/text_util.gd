class_name TextUtil
extends RefCounted
## Stateless display-text resolver for dialogue/UI strings.
## Same pattern as DirectionUtil: static helper, no autoload registration.
## Single choke point so token rules never drift between systems.
##
## Authoring rules (data/*.json):
##   "[Player]"  -> replaced with GameState.player_name
##   "\word"     -> marks an Akeanon word; the "\" is stripped at render time
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
## Longest name accepted by name entry.
const MAX_NAME_LENGTH: int = 12


## Returns `raw` with the player token substituted and Akeanon markers removed.
static func resolve(raw: String) -> String:
	var name_out: String = GameState.player_name.strip_edges()
	if name_out.is_empty():
		name_out = FALLBACK_NAME
	return raw.replace(PLAYER_TOKEN, name_out).replace(AKEANON_MARKER, "")


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
