# GameState.gd — Global game state, save/load, flags
extends Node

# --- Signals ---
signal word_learned(word_id: String, akeanon: String, gloss: String)
signal rapport_changed(npc_id: String, value: float)
signal patience_changed(npc_id: String, value: int)
signal reward_granted(reward_type: String, id_or_amount)
## Fired on every set_flag. Lets level scripts react to story flags (e.g.
## despawn cast on "chapter1_complete") without polling.
signal flag_changed(flag_name: String, value: bool)

# --- State ---
var flags: Dictionary = {}          # quest/story flags
var word_exposures: Dictionary = {} # word_id -> exposure count (doubles as Dictionary-unlock record)
var current_area: String = "village"
var completed_quests: Array = []
var current_level_path: String = "res://scenes/world/chapter1/us_bedroom.tscn"
## Where the player stood when they last exited: {level: scene path, position:
## Vector2}. Empty when there's nothing to resume. Game.gd writes it on exit and
## uses it up on the next level load, so doors and travel never see an old spot.
var exit_spot: Dictionary = {}
## True once this run holds a real game (loaded or freshly started). Only saves
## triggered by closing the window check it: without it, launching Game.tscn on
## its own would overwrite save.dat with blank state on close.
var session_active: bool = false

## In-game clock in hours (0..24, fractional), advanced by DayNightManager.
const DEFAULT_TIME_OF_DAY: float = 21.0  # 9 PM: the game opens at night
var time_of_day: float = DEFAULT_TIME_OF_DAY
## In-game date: unix seconds at 00:00 (UTC) of the current in-game day.
## DayNightManager adds a day each time the clock passes midnight. New games
## (and saves from before this field) start on START_DATE.
const START_DATE := {"year": 2026, "month": 11, "day": 15}
var date_unix: int = start_date_unix()

## Unix seconds at 00:00 of START_DATE.
static func start_date_unix() -> int:
	return Time.get_unix_time_from_datetime_dict({"year": START_DATE["year"], "month": START_DATE["month"], "day": START_DATE["day"], "hour": 0, "minute": 0, "second": 0})

## Hour the "daily" day starts: dailies (newspaper puzzle, word of the day,
## idle talk) turn over when the player wakes, not at midnight, so solving the
## puzzle at 1 AM and sleeping still gives a fresh one in the morning.
const DAILY_START_HOUR: float = 6.0

## date_unix of the current daily day: before DAILY_START_HOUR it is still
## yesterday.
func daily_date() -> int:
	return date_unix - (DayNightManager.SECONDS_PER_DAY if time_of_day < DAILY_START_HOUR else 0)

## Player-chosen display name. Empty until name entry completes (new game) or
## when loading a pre-name-entry save. TextUtil substitutes a fallback when empty.
var player_name: String = ""

## Dev-only chapter/scene skip menu toggle (Settings tab). Deliberately NOT
## in save_game()/load_game(), so it never leaks into a saved game: it's a
## device setting, kept in user://settings.cfg [dev] like the menu-style switch.
## Change it with set_dev_mode() so it's remembered.
var dev_mode: bool = false

const DEV_SETTINGS_PATH := "user://settings.cfg"
const DEV_SETTINGS_SECTION := "dev"
const DEV_SETTINGS_KEY := "dev_mode"
## Dev menu switch: show chapter cards and notes even in dev mode. Device
## setting like dev_mode, never in a save.
var dev_show_cards: bool = false
const DEV_SHOW_CARDS_KEY := "show_chapter_cards"

func _ready() -> void:
	_init_save_slots()
	var config := ConfigFile.new()
	if config.load(DEV_SETTINGS_PATH) == OK:
		dev_mode = bool(config.get_value(DEV_SETTINGS_SECTION, DEV_SETTINGS_KEY, false))
		dev_show_cards = bool(config.get_value(DEV_SETTINGS_SECTION, DEV_SHOW_CARDS_KEY, false))

## Turns dev mode on/off and remembers it across restarts.
func set_dev_mode(enabled: bool) -> void:
	dev_mode = enabled
	var config := ConfigFile.new()
	config.load(DEV_SETTINGS_PATH)  # keeps other keys; a missing file is fine
	config.set_value(DEV_SETTINGS_SECTION, DEV_SETTINGS_KEY, enabled)
	config.save(DEV_SETTINGS_PATH)

## Turns "chapter cards in dev mode" on/off and remembers it across restarts.
func set_dev_show_cards(enabled: bool) -> void:
	dev_show_cards = enabled
	var config := ConfigFile.new()
	config.load(DEV_SETTINGS_PATH)
	config.set_value(DEV_SETTINGS_SECTION, DEV_SHOW_CARDS_KEY, enabled)
	config.save(DEV_SETTINGS_PATH)

## True when chapter cards and notes should be skipped: dev mode, unless the
## Dev menu's "Chapter cards" switch is on.
func skips_cards() -> bool:
	return dev_mode and not dev_show_cards

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

# --- Pesos and inventory (docs/ECONOMY_PLAN.md) ---
# RewardManager is the only writer of pesos (award_pesos / spend_pesos).
# Money is never taken away except by the player choosing to spend it.
var pesos: int = 0
var inventory: Dictionary = {}          # item id (data/items.json) -> count
var allowance_date: int = 0             # daily_date() of the last morning allowance
var review_earn_date: int = 0           # daily_date() review_earned_today counts for
var review_earned_today: int = 0        # pesos earned from NPC Review on that day (daily cap)
var reviews_done: int = 0               # NPC Review activities finished, pass or fail (chapter goals)
var reviews_passed: int = 0             # NPC Review activities passed (chapter goals since v1.1.5)
var quest_offer_declined: Dictionary = {} # side quest id -> daily_date() the player said "not now"

## Inventory changed (shop, quests). HUD and panels refresh on it.
signal inventory_changed
## Pesos changed: new total and the change (negative when spent).
signal pesos_changed(total: int, delta: int)

func add_pesos(amount: int) -> void:
	pesos = maxi(0, pesos + amount)
	pesos_changed.emit(pesos, amount)

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

func add_item(item_id: String, count: int = 1) -> void:
	if item_id.is_empty() or count <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + count
	inventory_changed.emit()

## Removes up to count; false (and nothing removed) if there are not enough.
func remove_item(item_id: String, count: int = 1) -> bool:
	if not has_item(item_id, count):
		return false
	var left: int = get_item_count(item_id) - count
	if left <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = left
	inventory_changed.emit()
	return true

# --- World Tasks (environmental puzzles, additive to Challenge system above) ---
# Owned by TaskManager, storage lives here per register-on-ready/call-through-autoload
# pattern (TDD §2). Separate from challenges_passed -- world tasks are action-in-world
# (collect/interact), not answer-select, and are not gated by node-map unlock by default.
var active_tasks: Dictionary = {}    # task_id -> current_step_index (int)
var completed_tasks: Dictionary = {} # task_id -> bool

# --- Word Mastery (adaptive review, GDD 6.8) ---
# +1 when a word is used/identified correctly in a quiz, phrase builder or
# puzzle; -1 per wrong answer. Hidden weighting signal only -- low mastery
# raises a word's pick weight (WordBank.get_weighted_review_word). Never feeds
# rewards, rapport or patience, so the no-punishment rule (GDD 7) holds.
const MASTERY_MAX := 10
var word_mastery: Dictionary = {}    # word_id -> int, clamped 0..MASTERY_MAX

# --- Word of the Day (newspaper, WordBank.get_word_of_the_day) ---
var wotd_date: int = 0     # date_unix the word was picked on
var wotd_id: String = ""
var puzzle_solved_date: int = 0   # date_unix of the last solved daily puzzle
var word_taught_date: int = 0   # date_unix of the last extra word an NPC taught (IdleTalk)
var idle_steps: Dictionary = {}   # npc_id -> {date, step}: how far today's idle talk got (IdleTalk)
var mass_invite_date: int = 0     # date_unix of the last Sunday mass invitation
var event_reminder_date: int = 0  # date_unix of the last morning event-reminder check (HUD)
# {date, ...panel state} of a quit daily puzzle; ignored once the date moves on.
var puzzle_progress: Dictionary = {}

## One newspaper puzzle per in-game day.
func is_puzzle_solved_today() -> bool:
	return puzzle_solved_date == daily_date()

## One extra word from an NPC per in-game day.
func is_word_taught_today() -> bool:
	return word_taught_date == daily_date()

func mark_word_taught() -> void:
	word_taught_date = daily_date()

## Total mastery changed (HUD tier bar).
signal mastery_changed

## Apply a mastery delta (+1 correct / -1 wrong). Ignores empty ids.
func adjust_mastery(word_id: String, delta: int) -> void:
	if word_id.is_empty():
		return
	word_mastery[word_id] = clampi(word_mastery.get(word_id, 0) + delta, 0, MASTERY_MAX)
	mastery_changed.emit()

func get_mastery(word_id: String) -> int:
	return word_mastery.get(word_id, 0)

# --- Difficulty tier (from total mastery) ---
# Tier 2 is roughly Chapter 1's 39 words at 2 points each, tier 3 the 124 words
# through Chapter 2 at 2 points each. Follows the live total, so it can drop.
## Total mastery that starts tier 2 and tier 3.
const DIFFICULTY_TIER_MASTERY: Array[int] = [75, 250]
const MINIGAME_BASE_WORDS: int = 4
const QUIZ_BASE_CHOICES: int = 5
## Dynamic quizzes scale their choices once the player knows more words than this.
const QUIZ_SCALE_MIN_KNOWN: int = 5

func get_total_mastery() -> int:
	var total: int = 0
	for points in word_mastery.values():
		total += int(points)
	return total

## 1, 2 or 3.
func get_difficulty_tier() -> int:
	var total: int = get_total_mastery()
	var tier: int = 1
	for threshold in DIFFICULTY_TIER_MASTERY:
		if total >= threshold:
			tier += 1
	return tier

## How far through the current tier, 0..1. The last tier always reads full.
func get_tier_progress() -> float:
	var tier: int = get_difficulty_tier()
	if tier > DIFFICULTY_TIER_MASTERY.size():
		return 1.0
	var start: int = DIFFICULTY_TIER_MASTERY[tier - 2] if tier > 1 else 0
	return float(get_total_mastery() - start) / float(DIFFICULTY_TIER_MASTERY[tier - 1] - start)

## Words in a crossword or word search, pairs in review memory match.
func get_minigame_word_count() -> int:
	return MINIGAME_BASE_WORDS + get_difficulty_tier()

## Choices per dynamic quiz question, or 0 while the player knows too few words
## to scale (the quiz keeps its default).
func get_quiz_choice_count() -> int:
	if word_exposures.size() <= QUIZ_SCALE_MIN_KNOWN:
		return 0
	return QUIZ_BASE_CHOICES + get_difficulty_tier()

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

# --- Save slots ---
# Three games side by side: <save_dir>/save_<slot>.dat. Each save is written to
# save_<slot>.tmp first and then swapped in, so a crash mid-write can't damage the
# real file; the previous save stays as save_<slot>.bak and is used if the main
# file can't be read. The main menu picks the slot (save_slot) before New Game or
# Continue. Test runs pass "--save-dir=user://playtest/<name>/" after "--" so they
# never touch the player's slots.
const SLOT_COUNT := 3
## Before save slots there was one game, user://save.dat. It becomes slot 1.
const LEGACY_SAVE_PATH := "user://save.dat"
const LEGACY_BACKUP_PATH := "user://save.bak"
## Slot last played, remembered in settings.cfg so Continue starts there.
const SLOT_SETTINGS_SECTION := "save"
const SLOT_SETTINGS_KEY := "last_slot"
var save_slot: int = 1
var save_dir: String = "user://"

func _save_path(slot: int = 0) -> String:
	return save_dir.path_join("save_%d.dat" % (slot if slot > 0 else save_slot))

func _save_temp_path(slot: int = 0) -> String:
	return save_dir.path_join("save_%d.tmp" % (slot if slot > 0 else save_slot))

func _save_backup_path(slot: int = 0) -> String:
	return save_dir.path_join("save_%d.bak" % (slot if slot > 0 else save_slot))

## Reads "--save-dir=" (test runs) and moves a pre-slots save into slot 1.
func _init_save_slots() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save-dir="):
			save_dir = a.substr(11)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
			return  # test runs keep their own folder; no migration, no last-slot memory
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(_save_path(1)):
		DirAccess.rename_absolute(LEGACY_SAVE_PATH, _save_path(1))
		if FileAccess.file_exists(LEGACY_BACKUP_PATH) and not FileAccess.file_exists(_save_backup_path(1)):
			DirAccess.rename_absolute(LEGACY_BACKUP_PATH, _save_backup_path(1))
	var config := ConfigFile.new()
	if config.load(DEV_SETTINGS_PATH) == OK:
		save_slot = clampi(int(config.get_value(SLOT_SETTINGS_SECTION, SLOT_SETTINGS_KEY, 1)), 1, SLOT_COUNT)

## Makes slot the one save_game()/load_game() use, and remembers it for Continue.
func use_slot(slot: int) -> void:
	save_slot = clampi(slot, 1, SLOT_COUNT)
	if save_dir != "user://":
		return
	var config := ConfigFile.new()
	config.load(DEV_SETTINGS_PATH)  # keep the other settings in the file
	config.set_value(SLOT_SETTINGS_SECTION, SLOT_SETTINGS_KEY, save_slot)
	config.save(DEV_SETTINGS_PATH)

## What the slot picker shows: {exists, name, chapter, saved (unix time)}.
func slot_summary(slot: int) -> Dictionary:
	var path := _save_path(slot)
	var data: Variant = _read_save(path)
	if data == null:
		path = _save_backup_path(slot)
		data = _read_save(path)
	if data == null:
		return {"exists": false}
	var f: Dictionary = data.get("flags", {})
	var chapter := 1
	for n in range(6, 1, -1):
		if f.get("chapter%d_started" % n, false) or f.get("seen_chapter%d_scene0" % n, false):
			chapter = n
			break
	return {"exists": true, "name": str(data.get("player_name", "")), "chapter": chapter,
		"saved": FileAccess.get_modified_time(path)}

## Removes a slot's save and backup.
func delete_slot(slot: int) -> void:
	for p in [_save_path(slot), _save_backup_path(slot), _save_temp_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

# --- Flag System ---
func set_flag(flag_name: String, value: bool = true) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)
	# A newly-set flag may satisfy a quest's "requires_flag" gate -- recheck so
	# the quest appears the moment the flag flips (idempotent, only appends).
	if value:
		QuestManager.refresh_active_quests()

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
	# Persist on FIRST exposure only: a hard force-quit before any other save
	# trigger (flag/quest/travel) would otherwise drop the new Dictionary entry.
	# Repeat exposures skipped -- count-only change, not worth a disk write.
	if is_new:
		save_game()

func get_exposure(word_id: String) -> int:
	return word_exposures.get(word_id, 0)

func is_in_dictionary(word_id: String) -> bool:
	return word_exposures.has(word_id)

## Reset every persisted field before starting a fresh run in the same process.
## Autoloads survive scene changes, so deleting save.dat alone leaves stale state in memory.
func reset_game_state() -> void:
	flags.clear()
	word_exposures.clear()
	current_area = "village"
	completed_quests.clear()
	current_level_path = "res://scenes/world/chapter1/us_bedroom.tscn"
	exit_spot = {}
	session_active = true
	time_of_day = DEFAULT_TIME_OF_DAY
	date_unix = start_date_unix()
	player_name = ""
	rapport.clear()
	patience.clear()
	_patience_last_update.clear()
	akeanon_stars = 0
	culture_badges.clear()
	travel_stamps.clear()
	grandma_memory_pages.clear()
	rose_hint_tokens = 0
	challenges_passed.clear()
	challenge_attempts.clear()
	pesos = 0
	inventory = {}
	allowance_date = 0
	review_earn_date = 0
	review_earned_today = 0
	reviews_done = 0
	reviews_passed = 0
	quest_offer_declined = {}
	pesos_changed.emit(pesos, 0)
	inventory_changed.emit()
	active_tasks.clear()
	completed_tasks.clear()
	word_mastery.clear()
	wotd_date = 0
	wotd_id = ""
	puzzle_solved_date = 0
	word_taught_date = 0
	idle_steps = {}
	mass_invite_date = 0
	event_reminder_date = 0
	puzzle_progress = {}
	# QuestManager is an autoload too; discard prior-run quest availability before rebuilding it.
	QuestManager.active_quests.clear()
	QuestManager.refresh_active_quests()


# --- Save/Load ---
func save_game() -> bool:
	var data = {
		"flags": flags,
		"word_exposures": word_exposures,
		"current_area": current_area,
		"completed_quests": completed_quests,
		"current_level_path": current_level_path,
		"exit_spot": exit_spot,
		"time_of_day": time_of_day,
		"date_unix": date_unix,
		"player_name": player_name,
		"rapport": rapport,
		"patience": patience,
		"patience_last_update": _patience_last_update,
		"akeanon_stars": akeanon_stars,
		"culture_badges": culture_badges,
		"travel_stamps": travel_stamps,
		"grandma_memory_pages": grandma_memory_pages,
		"rose_hint_tokens": rose_hint_tokens,
		"challenges_passed": challenges_passed,
		"challenge_attempts": challenge_attempts,
		"pesos": pesos,
		"inventory": inventory,
		"allowance_date": allowance_date,
		"review_earn_date": review_earn_date,
		"review_earned_today": review_earned_today,
		"reviews_done": reviews_done,
		"reviews_passed": reviews_passed,
		"quest_offer_declined": quest_offer_declined,
		"active_tasks": active_tasks,
		"completed_tasks": completed_tasks,
		"word_mastery": word_mastery,
		"wotd_date": wotd_date,
		"wotd_id": wotd_id,
		"puzzle_solved_date": puzzle_solved_date,
		"word_taught_date": word_taught_date,
		"idle_steps": idle_steps,
		"mass_invite_date": mass_invite_date,
		"event_reminder_date": event_reminder_date,
		"puzzle_progress": puzzle_progress
	}
	var temp_path := _save_temp_path()
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState.save_game: cannot open %s for writing (error %d)" % [temp_path, FileAccess.get_open_error()])
		return false

	file.store_var(data)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_error("GameState.save_game: failed writing %s (error %d)" % [temp_path, write_error])
		return false
	return _swap_in_saved_file()

## Keeps the current save as the backup and makes the finished temp file the save.
func _swap_in_saved_file() -> bool:
	var path := _save_path()
	var backup := _save_backup_path()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(path, backup)
	var error := DirAccess.rename_absolute(_save_temp_path(), path)
	if error != OK:
		push_error("GameState.save_game: could not replace %s (error %d)" % [path, error])
		return false
	return true

## True if there's anything Continue could try to load in slot (0 = the current slot).
func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_save_path(slot)) or FileAccess.file_exists(_save_backup_path(slot))

## True if any slot has a game.
func has_any_save() -> bool:
	for s in range(1, SLOT_COUNT + 1):
		if has_save(s):
			return true
	return false

## The save at path, or null if it's missing, empty or damaged.
func _read_save(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0:
		return null
	var data: Variant = file.get_var()
	file.close()
	return data if data is Dictionary and data.has("current_level_path") else null

## Loads the save, falling back to the backup. False if neither can be read,
## and then nothing in the current state has been touched.
## One-time fixes for flags added after a save was made. Safe to run on every load.
func _migrate_flags() -> void:
	# chapter2_mass_attended (added 2026-11-16) is what lets Chapter 2 end. Older
	# saves only remember the last Sunday's answer, or being mid-mass-trip.
	if not get_flag("chapter2_mass_attended"):
		for evidence: String in ["chapter2_mass_went", "chapter2_mass_trip", "chapter2_mass_cathedral"]:
			if get_flag(evidence):
				flags["chapter2_mass_attended"] = true
				break

func load_game() -> bool:
	var data: Variant = _read_save(_save_path())
	if data == null:
		data = _read_save(_save_backup_path())
		if data == null:
			push_error("GameState.load_game: no readable save found")
			return false
		push_warning("GameState.load_game: main save unreadable, using the backup")
	flags = data.get("flags", {})
	word_exposures = data.get("word_exposures", {})
	current_area = data.get("current_area", "village")
	completed_quests = data.get("completed_quests", [])
	current_level_path = data.get("current_level_path")
	exit_spot = data.get("exit_spot", {})  # additive field, old saves -> spawn as before
	session_active = true
	time_of_day = data.get("time_of_day", DEFAULT_TIME_OF_DAY)  # additive field, old saves -> 9 PM
	date_unix = data.get("date_unix", start_date_unix())  # additive field, old saves -> START_DATE
	player_name = data.get("player_name", "")  # additive field, old saves -> ""
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
	pesos = int(data.get("pesos", 0))  # additive field, old saves -> 0
	inventory = data.get("inventory", {})  # additive field, old saves -> {}
	allowance_date = int(data.get("allowance_date", 0))  # additive field
	review_earn_date = int(data.get("review_earn_date", 0))  # additive field
	review_earned_today = int(data.get("review_earned_today", 0))  # additive field
	reviews_done = int(data.get("reviews_done", 0))  # additive field
	reviews_passed = int(data.get("reviews_passed", 0))  # additive field
	quest_offer_declined = data.get("quest_offer_declined", {})  # additive field
	pesos_changed.emit(pesos, 0)
	inventory_changed.emit()
	active_tasks = data.get("active_tasks", {})
	completed_tasks = data.get("completed_tasks", {})
	word_mastery = data.get("word_mastery", {})  # additive field, old saves -> {}
	wotd_date = data.get("wotd_date", 0)  # additive field, old saves -> 0
	wotd_id = data.get("wotd_id", "")  # additive field, old saves -> ""
	puzzle_solved_date = data.get("puzzle_solved_date", 0)  # additive field, old saves -> 0
	word_taught_date = data.get("word_taught_date", 0)  # additive field, old saves -> 0
	idle_steps = data.get("idle_steps", {})  # additive field, old saves -> {}
	mass_invite_date = data.get("mass_invite_date", 0)  # additive field, old saves -> 0
	event_reminder_date = data.get("event_reminder_date", 0)  # additive field, old saves -> 0
	puzzle_progress = data.get("puzzle_progress", {})  # additive field, old saves -> {}
	_migrate_flags()
	# QuestManager built its active list at boot, before flags/exposures were
	# loaded -- re-scan so flag-gated quests (requires_flag) show after Continue.
	QuestManager.refresh_active_quests()
	return true
