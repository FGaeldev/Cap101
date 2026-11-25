# lessons.gd -- story minigames as gates (v1.1.6 difficulty).
#
# Every story quiz / phrase builder / minigame line with a "failure" branch that
# differs from its "success" is a lesson. ChapterLoader stamps it with a
# "gate_id" ("chapter2/scene_2_market_talk#14"). The story plays on as before
# either way, but a failed lesson is recorded in GameState.missed_lessons and
# the next chapter's opening waits until it's retaken (chapter_goals.gd).
# Retakes come from Rose's talk menu (npc_generic.gd): the first one each
# in-game day is free, more that day cost RETAKE_PRICE.
extends RefCounted

const RETAKE_PRICE: int = 10
const GATE_TYPES: Array[String] = ["quiz", "phrase_builder", "minigame_trigger"]
## Repeatable activities that reuse a story scene: never gates.
const NOT_GATES: Array[String] = ["chapter3/scene_loleng_habi_habi"]

## ChapterLoader: stamps "gate_id" on each lesson line of a freshly loaded chapter.
static func stamp_chapter(chapter_id: String, data: Variant) -> void:
	if not data is Dictionary:
		return
	for scene_key in data:
		var lines: Variant = data[scene_key]
		if not lines is Array or NOT_GATES.has("%s/%s" % [chapter_id, scene_key]):
			continue
		for i in lines.size():
			var line: Variant = lines[i]
			if line is Dictionary and GATE_TYPES.has(str(line.get("type", ""))) \
					and line.has("failure") and line.get("failure") != line.get("success") \
					and not _leads_back(lines, line.get("failure"), i):
				line["gate_id"] = "%s/%s#%d" % [chapter_id, scene_key, i]

## True if the failure path can reach the lesson line again: the scene already
## makes the player retry on the spot, so it isn't a gate.
static func _leads_back(lines: Array, start: Variant, target: int) -> bool:
	var todo: Array = [start]
	var seen: Dictionary = {}
	while not todo.is_empty():
		var at: Variant = todo.pop_back()
		if not (at is int or at is float):
			continue
		var i: int = int(at)
		if i == target:
			return true
		if i < 0 or i >= lines.size() or seen.has(i) or not lines[i] is Dictionary:
			continue
		seen[i] = true
		var l: Dictionary = lines[i]
		for key in ["next", "success", "failure"]:
			todo.append(l.get(key))
		for c in l.get("choices", []):
			if c is Dictionary:
				todo.append(c.get("next"))
	return false

## Comp_Dialogue, after a lesson line resolves (story or retake).
static func record(line: Dictionary, passed: bool) -> void:
	var gate_id: String = str(line.get("gate_id", ""))
	if gate_id.is_empty():
		return
	if passed and GameState.missed_lessons.has(gate_id):
		GameState.missed_lessons.erase(gate_id)
		ChapterCard.show_notice("Lesson retaken", label(gate_id), "Passed")
	elif not passed and not GameState.missed_lessons.has(gate_id):
		GameState.missed_lessons[gate_id] = true
		ChapterCard.show_notice("Lesson missed", label(gate_id), "Retake with Rose")
	# Flag watchers (chapter goals, HUD) re-check on flag changes.
	GameState.set_flag("lessons_missed", not GameState.missed_lessons.is_empty())

static func missed_count() -> int:
	return GameState.missed_lessons.size()

## "Ch2 · Market talk" from "chapter2/scene_2_market_talk#14".
static func label(gate_id: String) -> String:
	var chapter: String = gate_id.get_slice("/", 0).trim_prefix("chapter")
	var scene: String = gate_id.get_slice("/", 1).get_slice("#", 0).trim_prefix("scene_")
	# Drop the scene number ("2_", "1b_") and the practice-round prefix.
	var parts: PackedStringArray = scene.split("_", false)
	if not parts.is_empty() and parts[0].left(1).is_valid_int():
		parts.remove_at(0)
	var words: String = " ".join(parts).replace("vocabulary practice round ", "")
	return "Ch%s · %s" % [chapter, words.left(1).to_upper() + words.substr(1)]

## The lesson line for a gate id, or {} if the data moved.
static func line_for(gate_id: String) -> Dictionary:
	var chapter: String = gate_id.get_slice("/", 0)
	var rest: String = gate_id.get_slice("/", 1)
	var lines: Array = ChapterLoader.get_scene_lines(chapter, rest.get_slice("#", 0))
	var index: int = int(rest.get_slice("#", 1))
	if index < 0 or index >= lines.size() or str(lines[index].get("gate_id", "")) != gate_id:
		return {}
	return lines[index]

## True if today's retake is still free.
static func retake_is_free() -> bool:
	return GameState.lesson_retake_date != GameState.daily_date()

## Rose's menu label, e.g. "Retake a lesson (2 left, free today)".
static func menu_label() -> String:
	return "Retake a lesson (%d left, %s)" % [missed_count(), "free today" if retake_is_free() else "₱%d" % RETAKE_PRICE]

## Rose's "Retake a lesson": the oldest missed lesson, after paying if today's
## free retake is used. Lessons whose line no longer exists are dropped.
static func retake(rose: Node) -> void:
	var gate_id: String = ""
	for id: String in GameState.missed_lessons.keys():
		if line_for(id).is_empty():
			GameState.missed_lessons.erase(id)
			continue
		gate_id = id
		break
	if gate_id.is_empty():
		GameState.set_flag("lessons_missed", false)
		return
	if not retake_is_free():
		if not await _say(rose, [{"speaker": "Rose", "text": "Again today? Then buy us merienda first, and we'll go over it.", "next": null}]):
			return
		if not await Economy.pay(RETAKE_PRICE, "retake_price"):
			await _say(rose, [{"speaker": "Rose", "text": "Tomorrow, then. It's free in the morning.", "next": null}])
			return
	GameState.lesson_retake_date = GameState.daily_date()
	var lesson: Dictionary = line_for(gate_id).duplicate(true)
	lesson["success"] = 2
	lesson["failure"] = 3
	lesson.erase("next")
	await _say(rose, [
		{"speaker": "Rose", "text": "Okay, let's go over %s again." % label(gate_id).get_slice("· ", 1).to_lower(), "next": 1},
		lesson,
		{"speaker": "Rose", "text": "There. You've got it now.", "next": null},
		{"speaker": "Rose", "text": "Not yet. We'll try again another time.", "next": null},
	])
	GameState.save_game()

## Plays lines on Rose and waits for them to end. False if she's gone.
static func _say(rose: Node, lines: Array) -> bool:
	if not is_instance_valid(rose):
		return false
	var dialogue := DialogueComponent.new()
	dialogue.npc_id = "Rose"
	dialogue.dialogue_lines = lines
	rose.add_child(dialogue)
	dialogue.start_dialogue()
	await dialogue.dialogue_ended
	dialogue.queue_free()
	return is_instance_valid(rose)
