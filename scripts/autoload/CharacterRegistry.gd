# CharacterRegistry.gd
# Central speaker_id -> portrait map. One place to add a character.
# Scales to N speakers per scene without touching DialogueComponent.
extends Node

const DATA_PATH := "res://data/characters/character_portraits.tres"

var _portraits: Dictionary = {}  # speaker_id (lowercase) -> Texture2D

func _ready() -> void:
	var data: CharacterRegistryData = load(DATA_PATH)
	if data == null:
		push_error("CharacterRegistry: missing %s" % DATA_PATH)
		return
	for entry in data.entries:
		_portraits[entry.speaker_id.to_lower()] = entry.portrait

func get_portrait(speaker_id: String) -> Texture2D:
	return _portraits.get(speaker_id.to_lower(), null)
