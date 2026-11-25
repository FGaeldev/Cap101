# side_quests.gd -- fetch quests (docs/ECONOMY_PLAN.md). Static helper, like
# IdleTalk: builds the dialogue an NPC says about their side quest, if any.
#
# A side quest is a quest_data.json entry with "category": "side" and a "giver"
# (the NPC's npc_id). Its "requires_flag" is the flag set when the player
# accepts, so QuestManager shows it as active from then on. Fields:
#   offer_flag   : the giver offers the quest once this story flag is set
#   offer_condition: optional NpcSchedule condition that must hold right now
#                  (e.g. "mass_skipped": only while the others are at mass)
#   offer_spot   : optional culture spot id whose person must be out now
#                  ("taho_vendor": only on the mornings the taho man comes)
#   offer_dates  : optional {from: [month, day], to: [month, day]} (holidays)
#   unless_flag  : never offered or reminded once this flag is set
#   start_pesos  : money the giver hands over on accepting (to buy with)
#   needs_items  : {item id: count} the player brings back (data/items.json)
#   reward_rapport: hearts with the giver on hand-in
#   reward_pesos : thank-you money on hand-in, on top of any change
#   lines        : economy_lines.json keys: offer (array), yes, no, later,
#                  remind, thanks
# Handing in takes the items and completes the quest. Money is never taken:
# the player keeps any change.
extends RefCounted

const SIDE_CATEGORY := "side"
const CultureSpots := preload("res://scripts/util/culture_spots.gd")

## Dialogue lines for the giver's side quest, or [] (then normal talk runs).
static func lines_for(npc_id: String) -> Array:
	# Time-limited quests (holiday dates, a random-day vendor) come first, so
	# they aren't missed behind an ordinary errand the giver also has.
	var ids: Array = QuestManager.quests.keys()
	var timed: Array = ids.filter(func(id: String) -> bool:
		return QuestManager.quests[id].has("offer_dates") or QuestManager.quests[id].has("offer_spot"))
	for qid: String in timed + ids.filter(func(id: String) -> bool: return not timed.has(id)):
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") != SIDE_CATEGORY or q.get("giver", "") != npc_id:
			continue
		if GameState.get_flag(str(q.get("completion_flag", ""))):
			continue
		# The story moved past it (packing for the flight once in Aklan).
		var unless_flag: String = str(q.get("unless_flag", ""))
		if not unless_flag.is_empty() and GameState.get_flag(unless_flag):
			continue
		var accepted: bool = GameState.get_flag(str(q.get("requires_flag", "")))
		if accepted:
			return _hand_in_lines(qid, q) if has_all_items(q) else [_line(q, "remind")]
		if _can_offer(qid, q):
			return _offer_lines(qid, q)
	return []

## True if this giver has an errand to offer now, or one ready to hand in
## (npc_generic.wants_marker). An accepted errand still being shopped for: false.
static func has_something(npc_id: String) -> bool:
	for qid: String in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") != SIDE_CATEGORY or q.get("giver", "") != npc_id:
			continue
		if GameState.get_flag(str(q.get("completion_flag", ""))):
			continue
		var unless_flag: String = str(q.get("unless_flag", ""))
		if not unless_flag.is_empty() and GameState.get_flag(unless_flag):
			continue
		if GameState.get_flag(str(q.get("requires_flag", ""))):
			if has_all_items(q):
				return true
		elif _can_offer(qid, q):
			return true
	return false

## Hand-in lines if the player carries everything an accepted quest from this
## giver needs, else []. NPCs check this before a talk cutscene (Rose's "Can we
## go out again?"), so finished errands can be handed in wherever the giver is.
static func hand_in_lines_for(npc_id: String) -> Array:
	for qid: String in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") != SIDE_CATEGORY or q.get("giver", "") != npc_id:
			continue
		if GameState.get_flag(str(q.get("completion_flag", ""))):
			continue
		if GameState.get_flag(str(q.get("requires_flag", ""))) and has_all_items(q):
			return _hand_in_lines(qid, q)
	return []

## True if the player carries everything the quest asks for.
static func has_all_items(q: Dictionary) -> bool:
	var needs: Dictionary = q.get("needs_items", {})
	for item_id: String in needs:
		if not GameState.has_item(item_id, int(needs[item_id])):
			return false
	return true

## "bugas 1/1, uga 0/1" style progress for the Quests panel.
static func item_progress(q: Dictionary) -> String:
	var parts: Array[String] = []
	var needs: Dictionary = q.get("needs_items", {})
	for item_id: String in needs:
		var need: int = int(needs[item_id])
		parts.append("%s (%s) %d/%d" % [Economy.item_word(item_id), Economy.item_name(item_id).to_lower(),
				mini(GameState.get_item_count(item_id), need), need])
	return ", ".join(parts)

static func _can_offer(qid: String, q: Dictionary) -> bool:
	var offer_flag: String = str(q.get("offer_flag", ""))
	if not offer_flag.is_empty() and not GameState.get_flag(offer_flag):
		return false
	var offer_condition: String = str(q.get("offer_condition", ""))
	if not offer_condition.is_empty() and not NpcSchedule.condition(offer_condition):
		return false
	var offer_spot: String = str(q.get("offer_spot", ""))
	if not offer_spot.is_empty() and not CultureSpots.is_spot_out(offer_spot):
		return false
	if q.has("offer_dates") and not _in_dates(q["offer_dates"]):
		return false
	# "Not now" today means she asks again tomorrow, not on every Talk.
	return int(GameState.quest_offer_declined.get(qid, -1)) != GameState.daily_date()

## offer_dates {"from": [month, day], "to": [month, day]}, inclusive, within one
## year (Dec 20 to Dec 24). Uses the in-game date.
static func _in_dates(dates: Dictionary) -> bool:
	var d: Dictionary = DayNightManager.get_date()
	var today: int = int(d["month"]) * 100 + int(d["day"])
	var from: Array = dates.get("from", [1, 1])
	var to: Array = dates.get("to", [12, 31])
	return today >= int(from[0]) * 100 + int(from[1]) and today <= int(to[0]) * 100 + int(to[1])

static func _line(q: Dictionary, key: String, extra: Dictionary = {}) -> Dictionary:
	var line_key: String = str(q.get("lines", {}).get(key, ""))
	var src: Dictionary = Economy.line(line_key)
	var out: Dictionary = {"speaker": src["speaker"], "text": src["text"], "word_ids": src["word_ids"]}
	out.merge(extra, true)
	return out

static func _offer_lines(qid: String, q: Dictionary) -> Array:
	var out: Array = []
	for key: String in q.get("lines", {}).get("offer", []):
		out.append(Economy.line(key))
	var lines: Array = []
	for l: Dictionary in out:
		lines.append({"speaker": l["speaker"], "text": l["text"], "word_ids": l["word_ids"]})
	var yes_text: String = str(Economy.line(str(q["lines"].get("yes", ""))).get("text", "Yes"))
	var no_text: String = str(Economy.line(str(q["lines"].get("no", ""))).get("text", "Not now"))
	# The last offer line carries the choice. Yes: the giver repeats the list
	# (remind) as the money and quest are handed over. Not now: the later line.
	var choice_at: int = lines.size() - 1
	var accept_at: int = lines.size()
	var later_at: int = accept_at + 1
	lines[choice_at]["choices"] = [
		{"label": yes_text, "next": accept_at},
		{"label": no_text, "next": later_at},
	]
	# "required": true (v1.1.9, packing for the flight): the story waits on it,
	# so there's no "Not now".
	if q.get("required", false):
		lines[choice_at]["choices"].pop_back()
	lines.append(_line(q, "remind", {"next": null, "on_enter": _accept.bind(qid)}))
	lines.append(_line(q, "later", {"next": null, "on_enter": _decline.bind(qid)}))
	return lines

static func _decline(qid: String) -> void:
	GameState.quest_offer_declined[qid] = GameState.daily_date()

static func _accept(qid: String) -> void:
	var q: Dictionary = QuestManager.quests.get(qid, {})
	var start_pesos: int = int(q.get("start_pesos", 0))
	if start_pesos > 0:
		RewardManager.award_pesos(start_pesos, "From " + str(q.get("giver", "")))
	GameState.quest_offer_declined.erase(qid)
	GameState.set_flag(str(q.get("requires_flag", "")))  # QuestManager starts it
	GameState.save_game()

static func _hand_in_lines(qid: String, q: Dictionary) -> Array:
	return [_line(q, "thanks", {"next": null, "on_enter": _hand_in.bind(qid)})]

static func _hand_in(qid: String) -> void:
	var q: Dictionary = QuestManager.quests.get(qid, {})
	if not has_all_items(q):
		return
	var needs: Dictionary = q.get("needs_items", {})
	for item_id: String in needs:
		GameState.remove_item(item_id, int(needs[item_id]))
	var thanks_pesos: int = int(q.get("reward_pesos", 0))
	if thanks_pesos > 0:
		RewardManager.award_pesos(thanks_pesos, "From " + str(q.get("giver", "")))
	var hearts: float = float(q.get("reward_rapport", 0.0))
	if hearts > 0.0:
		GameState.adjust_rapport(str(q.get("giver", "")), hearts)
	QuestManager.complete_quest(qid)  # saves
