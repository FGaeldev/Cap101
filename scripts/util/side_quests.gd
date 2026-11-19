# side_quests.gd -- fetch quests (docs/ECONOMY_PLAN.md). Static helper, like
# IdleTalk: builds the dialogue an NPC says about their side quest, if any.
#
# A side quest is a quest_data.json entry with "category": "side" and a "giver"
# (the NPC's npc_id). Its "requires_flag" is the flag set when the player
# accepts, so QuestManager shows it as active from then on. Fields:
#   offer_flag   : the giver offers the quest once this story flag is set
#   offer_condition: optional NpcSchedule condition that must hold right now
#                  (e.g. "mass_skipped": only while the others are at mass)
#   start_pesos  : money the giver hands over on accepting (to buy with)
#   needs_items  : {item id: count} the player brings back (data/items.json)
#   reward_rapport: hearts with the giver on hand-in
#   lines        : economy_lines.json keys: offer (array), yes, no, later,
#                  remind, thanks
# Handing in takes the items and completes the quest. Money is never taken:
# the player keeps any change.
extends RefCounted

const SIDE_CATEGORY := "side"

## Dialogue lines for the giver's side quest, or [] (then normal talk runs).
static func lines_for(npc_id: String) -> Array:
	for qid: String in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		if q.get("category", "") != SIDE_CATEGORY or q.get("giver", "") != npc_id:
			continue
		if GameState.get_flag(str(q.get("completion_flag", ""))):
			continue
		var accepted: bool = GameState.get_flag(str(q.get("requires_flag", "")))
		if accepted:
			return _hand_in_lines(qid, q) if has_all_items(q) else [_line(q, "remind")]
		if _can_offer(qid, q):
			return _offer_lines(qid, q)
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
	# "Not now" today means she asks again tomorrow, not on every Talk.
	return int(GameState.quest_offer_declined.get(qid, -1)) != GameState.daily_date()

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
	var hearts: float = float(q.get("reward_rapport", 0.0))
	if hearts > 0.0:
		GameState.adjust_rapport(str(q.get("giver", "")), hearts)
	QuestManager.complete_quest(qid)  # saves
