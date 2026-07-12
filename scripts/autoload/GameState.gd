# GameState.gd — Global game state, save/load, flags
extends Node

# --- State ---
var flags: Dictionary = {}          # quest/story flags
var word_exposures: Dictionary = {} # word_id -> exposure count (doubles as Dictionary-unlock record)
var current_area: String = "village"
var completed_quests: Array = []

const SAVE_PATH = "user://save.dat"

# --- Flag System ---
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value

func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

# --- Word Exposure (Ebbinghaus hook + Dictionary unlock) ---
# A word enters the player's Dictionary the moment it is first exposed.
# [CLAUDE NOTE] Per panel feedback: free-text "Notes" system removed.
# Dictionary now shows the verified gloss directly once a word is encountered.
func expose_word(word_id: String) -> void:
	word_exposures[word_id] = word_exposures.get(word_id, 0) + 1

func get_exposure(word_id: String) -> int:
	return word_exposures.get(word_id, 0)

func is_in_dictionary(word_id: String) -> bool:
	return word_exposures.has(word_id)

# --- Save/Load ---
func save_game() -> void:
	var data = {
		"flags": flags,
		"word_exposures": word_exposures,
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
	current_area = data.get("current_area", "village")
	completed_quests = data.get("completed_quests", [])
