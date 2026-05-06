# GameState.gd — Global game state, save/load, flags
extends Node

# --- State ---
var flags: Dictionary = {}          # quest/story flags
var word_exposures: Dictionary = {} # word_id -> exposure count
var player_notes: Dictionary = {}   # word_id -> player's written meaning
var current_area: String = "village"
var completed_quests: Array = []

const SAVE_PATH = "user://save.dat"

# --- Flag System ---
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

# --- Word Exposure (Ebbinghaus hook) ---
func expose_word(word_id: String) -> void:
	word_exposures[word_id] = word_exposures.get(word_id, 0) + 1

func get_exposure(word_id: String) -> int:
	return word_exposures.get(word_id, 0)

# --- Notes ---
func save_note(word_id: String, meaning: String) -> void:
	player_notes[word_id] = meaning

func get_note(word_id: String) -> String:
	return player_notes.get(word_id, "")

# --- Save/Load ---
func save_game() -> void:
	var data = {
		"flags": flags,
		"word_exposures": word_exposures,
		"player_notes": player_notes,
		"current_area": current_area,
		"completed_quests": completed_quests
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(data)
	file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = file.get_var()
	file.close()
	flags = data.get("flags", {})
	word_exposures = data.get("word_exposures", {})
	player_notes = data.get("player_notes", {})
	current_area = data.get("current_area", "village")
	completed_quests = data.get("completed_quests", [])
