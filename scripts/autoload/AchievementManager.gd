# AchievementManager.gd — autoload.
# Stub achievement system (Roadmap Phase A Journal-tab decision, GDD open
# question territory). Deliberately NOT persisted state — is_unlocked()
# recomputes from existing GameState fields (word_exposures, completed_quests,
# rapport) every call. Zero save-schema footprint, zero migration risk (TDD
# §7 rule: any new persistent field needs both save+load, additive only).
# No unlock-timestamp or first-time notification here — that's the natural
# next step once this stub is validated, not built here.
extends Node

const DATA_PATH := "res://data/achievements.json"

var achievements: Array = []  # ordered, each {id, title, description, condition}

func _ready() -> void:
	_load()

func _load() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("AchievementManager: failed to open %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("achievements"):
		push_error("AchievementManager: achievements.json malformed, expected {achievements: [...]}")
		return
	achievements = parsed["achievements"]

## Recomputed live, not cached — cheap given achievement count stays small
## (stub scale). Add a dirty-flag/cache layer only if this list grows large
## enough to matter on a real device.
func is_unlocked(ach: Dictionary) -> bool:
	var cond: Dictionary = ach.get("condition", {})
	match cond.get("type", ""):
		"word_count":
			return GameState.word_exposures.size() >= int(cond.get("min", 0))
		"quest_count":
			return GameState.completed_quests.size() >= int(cond.get("min", 0))
		"rapport_min":
			var threshold: float = cond.get("min", 0.0)
			for npc_id in GameState.rapport:
				if GameState.rapport[npc_id] >= threshold:
					return true
			return false
		_:
			push_warning("AchievementManager: unknown condition type '%s'" % cond.get("type", ""))
			return false
