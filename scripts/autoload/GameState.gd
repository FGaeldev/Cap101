# GameState.gd — Global game state, save/load, flags
extends Node

# --- Signals ---
signal word_learned(word_id: String, akeanon: String, gloss: String)
signal rapport_changed(npc_id: String, value: float)
signal patience_changed(npc_id: String, value: int)
signal reward_granted(reward_type: String, id_or_amount)

# --- State ---
var flags: Dictionary = {}          # quest/story flags
var word_exposures: Dictionary = {} # word_id -> exposure count (doubles as Dictionary-unlock record)
var current_area: String = "village"
var completed_quests: Array = []
var current_level_path: String = "res://scenes/world/scene01.tscn"

## Dev-only chapter/scene skip menu toggle (Settings tab). Deliberately NOT
## in save_game()/load_game() -- session-only, must never leak into a saved
## game or ship "on" by default from a stale save file.
var dev_mode: bool = false

# --- Rapport / Patience ---
# "Rapport regains around half per day"
# flat amount, prorated for partial days.
# Real-world clock based,
# not an in-game day counter (none exists yet).
# Relies on device clock
const PATIENCE_MAX := 100
const PATIENCE_REGEN_PER_DAY := 50.0 

var rapport: Dictionary = {}              # npc_id -> float, purely cumulative
var patience: Dictionary = {}             # npc_id -> float, regenerates over time
var _patience_last_update: Dictionary = {} # npc_id -> unix timestamp of last regen calc

const RAPPORT_MAX := 10.0  # displayed as 10 hearts, 0.5 increments = half-hearts

# --- Reward Economy (Ch2) ---
# Sole writer is RewardManager; GameState owns storage + mutation, per the
# adjust_rapport/adjust_patience pattern above.
var akeanon_stars: int = 0
var culture_badges: Array = []          # badge ids, no duplicates
var travel_stamps: Array = []           # stamp ids, no duplicates
var grandma_memory_pages: Array = []    # page ids, no duplicates
var rose_hint_tokens: int = 0
var challenges_passed: Dictionary = {}  # challenge_id -> bool
var challenge_attempts: Dictionary = {} # challenge_id -> int, attempt count (for first_try check)

func add_stars(amount: int) -> void:
	akeanon_stars += amount
	reward_granted.emit("stars", amount)

func add_badge(badge_id: String) -> void:
	if badge_id in culture_badges:
		return
	culture_badges.append(badge_id)
	reward_granted.emit("badge", badge_id)

func add_stamp(stamp_id: String) -> void:
	if stamp_id in travel_stamps:
		return
	travel_stamps.append(stamp_id)
	reward_granted.emit("stamp", stamp_id)

func add_memory_page(page_id: String) -> void:
	if page_id in grandma_memory_pages:
		return
	grandma_memory_pages.append(page_id)
	reward_granted.emit("memory_page", page_id)

func add_hint_tokens(amount: int) -> void:
	rose_hint_tokens += amount
	reward_granted.emit("hint_token", amount)

func spend_hint_token() -> bool:
	if rose_hint_tokens <= 0:
		return false
	rose_hint_tokens -= 1
	return true

func mark_challenge_passed(challenge_id: String) -> void:
	challenges_passed[challenge_id] = true

func is_challenge_passed(challenge_id: String) -> bool:
	return challenges_passed.get(challenge_id, false)

func record_challenge_attempt(challenge_id: String) -> int:
	challenge_attempts[challenge_id] = challenge_attempts.get(challenge_id, 0) + 1
	return challenge_attempts[challenge_id]

func get_challenge_attempts(challenge_id: String) -> int:
	return challenge_attempts.get(challenge_id, 0)

func adjust_rapport(npc_id: String, delta: float) -> void:
	rapport[npc_id] = clamp(rapport.get(npc_id, 0.0) + delta, 0.0, RAPPORT_MAX)
	rapport_changed.emit(npc_id, rapport[npc_id])

func get_rapport(npc_id: String) -> float:
	return rapport.get(npc_id, 0.0)

func adjust_patience(npc_id: String, delta: int) -> void:
	_regen_patience(npc_id)  # apply any pending regen before spending/adding
	var current: float = patience.get(npc_id, float(PATIENCE_MAX))
	patience[npc_id] = clamp(current + delta, 0.0, float(PATIENCE_MAX))
	_patience_last_update[npc_id] = Time.get_unix_time_from_system()
	patience_changed.emit(npc_id, int(patience[npc_id]))

func get_patience(npc_id: String) -> int:
	_regen_patience(npc_id)
	return int(patience.get(npc_id, PATIENCE_MAX))

func _regen_patience(npc_id: String) -> void:
	var now := Time.get_unix_time_from_system()
	if not _patience_last_update.has(npc_id):
		# first time this NPC's patience is ever touched — start full, no regen to apply
		patience[npc_id] = float(PATIENCE_MAX)
		_patience_last_update[npc_id] = now
		return
	var last_update: float = _patience_last_update[npc_id]
	var elapsed_days: float = (now - last_update) / 86400.0
	if elapsed_days <= 0.0:
		return
	var current: float = patience.get(npc_id, float(PATIENCE_MAX))
	var regained := elapsed_days * PATIENCE_REGEN_PER_DAY
	patience[npc_id] = min(float(PATIENCE_MAX), current + regained)
	_patience_last_update[npc_id] = now

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
	var is_new := not word_exposures.has(word_id)
	word_exposures[word_id] = word_exposures.get(word_id, 0) + 1
	if is_new:
		var w = WordBank.get_word(word_id)
		word_learned.emit(word_id, w.get("akeanon",""), w.get("gloss",""))
	# Exposure count feeds QuestManager's exposure-gate — recheck here so a
	# quest can go from locked to active_quests the moment its threshold
	# is crossed, not just at boot/quest-completion.
	QuestManager.refresh_active_quests()

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
		"completed_quests": completed_quests,
		"current_level_path": current_level_path,
		"rapport": rapport,
		"patience": patience,
		"patience_last_update": _patience_last_update,
		"akeanon_stars": akeanon_stars,
		"culture_badges": culture_badges,
		"travel_stamps": travel_stamps,
		"grandma_memory_pages": grandma_memory_pages,
		"rose_hint_tokens": rose_hint_tokens,
		"challenges_passed": challenges_passed,
		"challenge_attempts": challenge_attempts
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
	current_level_path = data.get("current_level_path")
	rapport = data.get("rapport", {})
	patience = data.get("patience", {})
	_patience_last_update = data.get("patience_last_update", {})
	akeanon_stars = data.get("akeanon_stars", 0)
	culture_badges = data.get("culture_badges", [])
	travel_stamps = data.get("travel_stamps", [])
	grandma_memory_pages = data.get("grandma_memory_pages", [])
	rose_hint_tokens = data.get("rose_hint_tokens", 0)
	challenges_passed = data.get("challenges_passed", {})
	challenge_attempts = data.get("challenge_attempts", {})
