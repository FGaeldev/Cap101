# CharacterRegistry.gd
# Central speaker_id -> portrait map. One place to add a character.
# Scales to N speakers per scene without touching DialogueComponent.
extends Node

const DATA_PATH := "res://data/characters/character_portraits.tres"
const PLAYER_ID := "Player"

var _portraits: Dictionary = {}  # speaker_id (lowercase) -> Texture2D
var _speaker_ids: Array[String] = []  # original-case, in registry order

func _ready() -> void:
	var data: CharacterRegistryData = load(DATA_PATH)
	if data == null:
		push_error("CharacterRegistry: missing %s" % DATA_PATH)
		return
	for entry in data.entries:
		_portraits[entry.speaker_id.to_lower()] = entry.portrait
		# The player has a portrait but no relationship row.
		if entry.speaker_id != PLAYER_ID:
			_speaker_ids.append(entry.speaker_id)

## The name token "[Player]" and "Player" share a portrait.
func get_portrait(speaker_id: String) -> Texture2D:
	return _portraits.get(speaker_id.to_lower().trim_prefix("[").trim_suffix("]"), null)

## Full roster of registered speakers, in original-case form (Lola Jonabel,
## not lola jonabel) — used by the Relationship page's NPC list.
func get_all_speaker_ids() -> Array[String]:
	return _speaker_ids
