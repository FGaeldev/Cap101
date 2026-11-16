extends SceneTree
# Cap101 auto-player. Plays the real game by itself and records every error,
# warning and stall it hits, with a screenshot of the screen at that moment.
#
#   godot --path <project> --script autoplay.gd -- --mode=full --out=<dir>
#   godot --path <project> --script autoplay.gd -- --mode=chapter --chapter=2 --out=<dir>
#
# Options (after the bare "--"):
#   --mode=full|chapter   full: every available chapter in order from a new game.
#                         chapter: one chapter, starting from that chapter's start state.
#   --chapter=N           chapter for --mode=chapter.
#   --out=DIR             where events.log, findings.json and shots/ go (required).
#   --budget=SEC          real-time limit (default 900 per chapter).
#   --speed=X             Engine.time_scale floor (default 3).
#   --no-fast-calendar    don't jump the clock to Saturday night after the Ch2 tour
#                         (by default it does, so Sunday mass gets tested quickly).
#
# Must run WINDOWED (not --headless): screenshots need a real frame.
# Overwrites user://save.dat while it runs -- run.sh backs it up and restores it.

const IDLE_SETTLE_MS := 700
const MAX_SHOTS := 60
const LOG_TAIL := 25

## Per-chapter setup and finish line. Add an entry when a chapter becomes playable.
##   start_level  level a chapter-mode run boots into
##   setup        name of the func that forces the state the chapter starts from
##   done         name of the func that returns true once the chapter is played out
const CHAPTERS := {
	1: {"start_level": "res://scenes/world/chapter1/us_bedroom.tscn", "setup": "_setup_ch1", "done": "_done_ch1"},
	2: {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_ch2", "done": "_done_ch2"},
	3: {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_ch3", "done": "_done_ch3"},
}

var opts := {"mode": "full", "chapter": 1, "out": "", "budget": 0.0, "speed": 3.0, "fast_calendar": true}
var _chapters: Array = []      # chapter numbers this run plays, in order
var _chapter_i := 0
var _phase := 0
var _t0 := 0
var A := {}
var _ended := false
var _headless := false

# events + findings
var _log_file: FileAccess
var _tail: Array[String] = []
var _findings: Array = []          # dictionaries, see _add_finding
var _finding_index := {}           # key -> index in _findings
var _shot_queue: Array = []        # finding indexes waiting for a screenshot
var _capturing := false
var _shots := 0
var _logger: Logger
var _pending_errors: Array = []    # filled by the Logger (any thread), drained in _process
var _err_mutex := Mutex.new()

# driver state
var _last_line_key := ""
var _epoch := 0
var _tried := {}
var _touched_objects := {}
var _choice_seen := {}
var _mg_seen := {}
var _idle_since := -1
var _active_since := -1
var _busy_since := -1
var _last_level := ""
var _levels_shot := {}
var _review_done := 0
var _sleeps := 0
var _no_action_rounds := 0
var _warp_runs := {}
var _explore_steps := 0
var _want_sleep := false
var _jump_sunday := false
var _want_bakhawan := false
var _bakhawan_went := false
var _mass_done := false
var _wait_until := -1


class CaptureLogger extends Logger:
	var owner_tree
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		var bt := ""
		for b in script_backtrace:
			bt += b.format()
		owner_tree._queue_error({"type": error_type, "code": code, "rationale": rationale,
			"where": "%s:%d (%s)" % [file, line, function], "backtrace": bt})
	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	auto_accept_quit = false
	_parse_args()
	_logger = CaptureLogger.new()
	_logger.owner_tree = self
	OS.add_logger(_logger)

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var kv := a.substr(2).split("=", true, 1)
		var k: String = kv[0]
		var v: String = kv[1] if kv.size() > 1 else ""
		match k:
			"mode": opts.mode = v
			"chapter": opts.chapter = int(v)
			"out": opts.out = v
			"budget": opts.budget = float(v)
			"speed": opts.speed = float(v)
			"no-fast-calendar": opts.fast_calendar = false

func _queue_error(e: Dictionary) -> void:
	_err_mutex.lock()
	_pending_errors.append(e)
	_err_mutex.unlock()

# --- output -------------------------------------------------------------------
func _p(msg: String) -> void:
	var secs := (Time.get_ticks_msec() - _t0) / 1000.0
	var clock: String = A.DayNightManager.format_clock() if A.has("DayNightManager") else "--:--"
	var lvl: String = A.GameState.current_level_path.get_file() if A.has("GameState") else ""
	var line := "[t=%6.1fs %s %s] %s" % [secs, clock, lvl, msg]
	print(line)
	if _log_file:
		_log_file.store_line(line)
		_log_file.flush()
	_tail.append(line)
	if _tail.size() > LOG_TAIL:
		_tail.pop_front()

## kind: error | warning | softlock | stuck | driver. Same kind+message = one finding, counted.
func _add_finding(kind: String, message: String, extra: Dictionary = {}) -> void:
	var key := kind + "|" + message
	if _finding_index.has(key):
		_findings[_finding_index[key]]["count"] += 1
		return
	var f := {
		"id": _findings.size() + 1, "kind": kind, "message": message, "count": 1,
		"chapter": _current_chapter(), "level": A.GameState.current_level_path if A.has("GameState") else "",
		"clock": A.DayNightManager.format_clock() if A.has("DayNightManager") else "",
		"t": (Time.get_ticks_msec() - _t0) / 1000.0, "screenshot": "",
		"context": _tail.duplicate(),
	}
	f.merge(extra)
	_finding_index[key] = _findings.size()
	_findings.append(f)
	if _log_file:
		_log_file.store_line("!!! FINDING #%d [%s] %s" % [f.id, kind, message])
	_shot_queue.append(_findings.size() - 1)

func _drain_errors() -> void:
	_err_mutex.lock()
	var errs := _pending_errors.duplicate()
	_pending_errors.clear()
	_err_mutex.unlock()
	for e in errs:
		var msg: String = e.code if e.rationale == "" else "%s (%s)" % [e.rationale, e.code]
		var kind := "warning" if e.type == 1 else "error"
		_add_finding(kind, msg, {"where": e.where, "backtrace": e.backtrace})

## Screenshots run as their own coroutine: wait for a drawn frame, then save it.
func _take_shot(name: String) -> String:
	if _headless or _shots >= MAX_SHOTS:
		return ""
	_capturing = true
	# Let UI tweens (dialogue box slide-in, toasts) land first. Real seconds, so
	# the driver's time_scale doesn't shorten it.
	await create_timer(0.35, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var rel := "shots/%s.png" % name
	img.save_png(opts.out.path_join(rel))
	_shots += 1
	_capturing = false
	return rel

func _service_shots() -> void:
	if _capturing or _shot_queue.is_empty():
		return
	var i: int = _shot_queue.pop_front()
	var f: Dictionary = _findings[i]
	var rel: String = await _take_shot("finding_%03d_%s" % [f.id, f.kind])
	f["screenshot"] = rel

func _write_findings(reason: String) -> void:
	var data := {
		"mode": opts.mode, "chapters": _chapters, "end_reason": reason,
		"seconds": (Time.get_ticks_msec() - _t0) / 1000.0, "headless": _headless,
		"final_level": A.GameState.current_level_path,
		"final_flags": A.GameState.flags.keys().filter(func(k): return A.GameState.flags[k]),
		"active_quests": A.QuestManager.active_quests,
		"levels_visited": _levels_shot,
		"findings": _findings,
	}
	var f := FileAccess.open(opts.out.path_join("findings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

# --- main loop ----------------------------------------------------------------
func _process(_delta: float) -> bool:
	if _ended:
		return false
	_drain_errors()
	_service_shots()
	match _phase:
		0:
			_start()
		1:
			_drive()
		2:
			# Finishing: let queued screenshots land, then quit.
			if _shot_queue.is_empty() and not _capturing:
				_ended = true
				Engine.time_scale = 1.0
				quit(0)
	return false

func _start() -> void:
	_t0 = Time.get_ticks_msec()
	_headless = DisplayServer.get_name() == "headless"
	if opts.out == "":
		push_error("autoplay: --out=DIR is required")
		quit(2)
		_ended = true
		return
	DirAccess.make_dir_recursive_absolute(opts.out.path_join("shots"))
	_log_file = FileAccess.open(opts.out.path_join("events.log"), FileAccess.WRITE)
	for n in ["GameState", "DialogueUI", "CutsceneManager", "MapManager", "TutorialManager",
			"ChapterCard", "BookUI", "DayNightManager", "QuestManager", "ChapterLoader", "NpcSchedule", "FadeManager", "ChapterLoader"]:
		A[n] = root.get_node(n)
	# Which chapters: chapters.json "available" ones that have a CHAPTERS entry.
	var playable: Array = []
	for ch in root.get_node("ChapterCard").get_chapters():
		if ch.get("available", false) and CHAPTERS.has(int(ch.number)):
			playable.append(int(ch.number))
	if opts.mode == "chapter":
		if not CHAPTERS.has(opts.chapter):
			_p("END: chapter %d has no autoplay definition (playable: %s)" % [opts.chapter, playable])
			_add_finding("driver", "chapter %d is not playable yet / not defined in autoplay.gd CHAPTERS" % opts.chapter)
			_finish("chapter not defined")
			return
		_chapters = [opts.chapter]
	else:
		_chapters = playable
	if opts.budget <= 0.0:
		opts.budget = 900.0 * _chapters.size()
	if _headless:
		_p("WARNING: running headless -- no screenshots will be taken")
	_p("START mode=%s chapters=%s budget=%ds" % [opts.mode, _chapters, int(opts.budget)])
	var GS = A.GameState
	GS.dev_mode = false
	GS.reset_game_state()
	GS.player_name = "Tester"
	GS.flag_changed.connect(_on_flag)
	A.QuestManager.quest_started.connect(func(q): _p("QUEST started " + q); _progress())
	A.QuestManager.quest_completed.connect(func(q): _p("QUEST completed " + q); _progress())
	A.CutsceneManager.cutscene_started.connect(func(c): _p("CUTSCENE start " + c))
	A.CutsceneManager.cutscene_finished.connect(func(c): _p("CUTSCENE end " + c))
	A.TutorialManager.tutorial_started.connect(func(t): _p("TUTORIAL start " + t))
	A.TutorialManager.tutorial_completed.connect(func(t): _p("TUTORIAL done " + t))
	A.DayNightManager.day_changed.connect(func(): _p("DAY -> %s" % str(A.DayNightManager.get_date())))
	# Chapter mode: force the state that chapter starts from.
	var first: int = _chapters[0]
	if first != 1 or opts.mode == "chapter":
		call(CHAPTERS[first].setup)
		GS.current_level_path = CHAPTERS[first].start_level
	change_scene_to_file("res://scenes/Game.tscn")
	_phase = 1

func _current_chapter() -> int:
	return _chapters[_chapter_i] if _chapter_i < _chapters.size() else -1

func _on_flag(flag: String, value: bool) -> void:
	_p("FLAG %s = %s" % [flag, value])
	_progress()
	if flag == "chapter2_tour_done" and value and opts.fast_calendar and _current_chapter() == 2:
		_jump_sunday = true
	if flag == "chapter2_mass_cathedral" and value:
		_want_bakhawan = true
		_mass_done = true  # the flag itself is cleared again once home
	if flag == "chapter2_going_bakhawan" and value:
		_bakhawan_went = true

func _progress() -> void:
	_epoch += 1
	_tried.clear()
	_no_action_rounds = 0
	_explore_steps = 0

func _finish(reason: String) -> void:
	_p("END: " + reason)
	_write_findings(reason)
	_phase = 2

# --- chapter definitions ------------------------------------------------------
func _setup_ch1() -> void:
	pass  # a new game is Chapter 1's start

func _done_ch1() -> bool:
	return A.GameState.get_flag("chapter1_complete") and A.GameState.current_level_path.contains("/chapter2/") \
		and not A.CutsceneManager.is_playing()

## Same state the airport exit leaves: Chapter 1 played out, nothing of Chapter 2 seen.
func _setup_ch2() -> void:
	var GS = A.GameState
	for f in ["chapter_card_chapter1_seen", "tutorial_ch1_basics_done", "tutorial_ch1_quest_hud_done",
			"tutorial_ch1_quests_done", "tutorial_ch1_dictionary_done", "tutorial_ch1_morning_done", "chapter1_slept",
			"tutorial_npc_menu_done", "seen_chapter1_scene1", "story_done_papa_jobert_scene1",
			"story_done_lola_jonabel_scene1", "seen_chapter1_scene1_5", "seen_chapter1_scene2", "seen_chapter1_scene3",
			"seen_chapter1_scene4", "story_done_scene_3_reunion", "story_done_scene_4_rose", "chapter1_complete"]:
		GS.set_flag(f)
	for q in ["q002", "q010", "q003", "q004"]:
		A.QuestManager.complete_quest_silently(q)

## Tour, Sunday mass and the Bakhawan trip all done, and home again.
func _done_ch2() -> bool:
	var GS = A.GameState
	return GS.get_flag("chapter2_tour_done") and _mass_done and _bakhawan_went \
		and not GS.get_flag("chapter2_with_rose") and not A.CutsceneManager.is_playing()

## The morning after Chapter 2 ended (tour + a mass, then a night's sleep), on a
## weekday at 7:00 so the morning brief plays instead of the Sunday mass invite.
func _setup_ch3() -> void:
	_setup_ch2()
	var GS = A.GameState
	for f in ["chapter_card_chapter2_seen", "seen_chapter2_scene0", "chapter2_slept", "seen_chapter2_scene0b",
			"seen_chapter2_scene1", "seen_chapter2_scene2", "seen_chapter2_scene3", "seen_chapter2_scene4",
			"chapter2_tour_done", "map_open_market", "chapter2_mass_attended", "chapter2_complete",
			"got_kalibo_map", "tutorial_ch2_map_done"]:
		GS.set_flag(f)
	var DN = root.get_node("DayNightManager")
	if DN.get_date()["weekday"] == 0:
		GS.date_unix += 86400
	DN.set_hour(7.0)
	GS.mass_invite_date = GS.date_unix

## Evening scene with Jonabel played.
func _done_ch3() -> bool:
	return A.GameState.get_flag("chapter3_complete") and not A.CutsceneManager.is_playing()

# --- driving ------------------------------------------------------------------
func _game() -> Node:
	return current_scene if current_scene and current_scene.name == "Game" else null

func _level() -> Node:
	var g := _game()
	if g == null:
		return null
	for c in g.get_node("LevelContainer").get_children():
		if not c.is_queued_for_deletion():
			return c
	return null

func _player() -> Node2D:
	var g := _game()
	return g.player if g else null

func _wait(ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if _wait_until < 0:
		_wait_until = now + ms
		return true
	if now < _wait_until:
		return true
	_wait_until = -1
	return false

func _drive() -> void:
	var now := Time.get_ticks_msec()
	if (now - _t0) / 1000.0 > opts.budget:
		_add_finding("stuck", "time budget (%ds) ran out before chapter %d finished" % [int(opts.budget), _current_chapter()])
		_finish("time budget reached")
		return
	if Engine.time_scale < opts.speed:
		Engine.time_scale = opts.speed
	if _game() == null:
		return
	# Hold still while a finding's screenshot is pending, so it shows that moment.
	if _capturing or not _shot_queue.is_empty():
		return
	# Chapter finished?
	if _chapter_i < _chapters.size() and call(CHAPTERS[_chapters[_chapter_i]].done):
		_p("CHAPTER %d COMPLETE" % _chapters[_chapter_i])
		_chapter_i += 1
		if _chapter_i >= _chapters.size():
			_finish("all requested chapters played")
			return
	var lvl_path: String = A.GameState.current_level_path
	if lvl_path != _last_level:
		_last_level = lvl_path
		_p("LEVEL " + lvl_path)
	if A.ChapterCard.visible:
		if not A.ChapterCard._continue_btn.disabled:
			_p("CHAPTER CARD: " + A.ChapterCard._title_label.text)
			A.ChapterCard._on_continue()
		return
	if A.BookUI.visible:
		if A.TutorialManager.is_running():
			_tutorial_step()
		if _wait(400):
			return
		_p("BOOKUI close")
		A.BookUI.close()
		return
	var DUI = A.DialogueUI
	for pair in [["phrase_builder", DUI._phrase_box], ["quiz", DUI._quiz_box], [str(DUI._minigame_type), DUI._minigame_box]]:
		var box = pair[1]
		if box != null and is_instance_valid(box) and box.visible:
			if _wait(500):
				return
			var n: int = _mg_seen.get(pair[0], 0)
			_mg_seen[pair[0]] = n + 1
			var passed := n != 0  # fail the first of each kind to cover failure branches
			_p("MINIGAME %s -> %s" % [pair[0], "pass" if passed else "FAIL"])
			box.resolved.emit(passed)
			return
	if DUI._newspaper_box != null and is_instance_valid(DUI._newspaper_box) and DUI._newspaper_box.visible:
		if _wait(400):
			return
		_p("NEWSPAPER close")
		DUI._newspaper_box.close()
		DUI.hide()
		return
	if DUI._npc_menu != null and is_instance_valid(DUI._npc_menu) and DUI._npc_menu.visible:
		if _wait(300):
			return
		var pick := "talk"
		if _review_done < 2 and A.GameState.get_flag("seen_chapter1_scene4"):
			pick = "review"
			_review_done += 1
		var who: String = DUI._npc_menu.get_node("NpcName").text if DUI._npc_menu.has_node("NpcName") else "?"
		_p("NPC MENU (%s) -> %s" % [who, pick])
		DUI._on_npc_interaction_choice(pick)
		return
	var comp = DUI._current_component
	if DUI._choice_box != null and DUI._choice_box.visible:
		if _wait(300):
			return
		var btns: Array = DUI._choice_box.choice_list.get_children().filter(func(b): return b is Button and not b.is_queued_for_deletion())
		if btns.is_empty():
			_add_finding("softlock", "choice box is showing with no buttons")
			return
		var prompt := ""
		if comp != null and is_instance_valid(comp) and comp._current_line < comp.dialogue_lines.size():
			prompt = str(comp.dialogue_lines[comp._current_line].get("text", ""))
		var key := prompt + "|" + "|".join(btns.map(func(b): return b.text))
		var rec: Dictionary = _choice_seen.get(key, {"count": 0, "epoch": -1})
		var idx := 0
		if rec["epoch"] == _epoch:
			idx = rec["count"] % btns.size()
		for bi in btns.size():
			if _want_bakhawan and "Bakhawan" in btns[bi].text:
				idx = bi
				_want_bakhawan = false
		rec["count"] += 1
		rec["epoch"] = _epoch
		_choice_seen[key] = rec
		_p("CHOICE [%s] -> '%s'  (options: %s)" % [prompt.left(70), btns[idx].text, " / ".join(btns.map(func(b): return b.text.left(30)))])
		btns[idx].pressed.emit()
		return
	if comp != null and is_instance_valid(comp) and DUI._root != null and DUI._root.visible:
		var lines: Array = comp.dialogue_lines
		var i: int = comp._current_line
		var key := "%d:%d" % [comp.get_instance_id(), i]
		if key != _last_line_key:
			_last_line_key = key
			_active_since = now
			if i < lines.size():
				var l: Dictionary = lines[i]
				_p("LINE %s: %s" % [l.get("speaker", ""), str(l.get("text", "")).left(110)])
				# A line authored with choices that shows none: the player can't answer it.
				if l.has("choices") and not l["choices"].is_empty() and not DUI._choice_box.visible:
					_add_finding("softlock", "line '%s' has choices but none are showing" % str(l.get("text", "")).left(60))
			if A.TutorialManager.is_running():
				_tutorial_step()
		if _wait(250):
			return
		DUI.player_pressed_advance()
		return
	if DUI.is_active():
		if _active_since < 0:
			_active_since = now
		elif now - _active_since > 8000:
			_add_finding("softlock", "dialogue UI is up but nothing on it can be advanced")
			_active_since = now
		return
	_active_since = -1
	if A.TutorialManager.is_running():
		_tutorial_step()
	if A.CutsceneManager.is_playing() or A.MapManager.is_transitioning:
		_idle_since = -1
		if _busy_since < 0:
			_busy_since = now
		elif A.MapManager.is_transitioning and not A.CutsceneManager.is_playing() and now - _busy_since > 20000:
			_add_finding("stuck", "a warp/transition has been running for 20s")
			_busy_since = now
		elif now - _busy_since > 180000:
			_add_finding("stuck", "a cutscene has been playing for 3 minutes")
			_busy_since = now
		return
	_busy_since = -1
	if _idle_since < 0:
		_idle_since = now
		return
	if now - _idle_since < IDLE_SETTLE_MS:
		return
	_idle_since = -1
	# Each new level, once it has settled: one overview screenshot (report context).
	if not _levels_shot.has(lvl_path):
		_levels_shot[lvl_path] = ""
		_shot_level(lvl_path)
		return
	_act()

func _shot_level(path: String) -> void:
	var rel: String = await _take_shot("level_%02d_%s" % [_levels_shot.size(), path.get_file().get_basename()])
	_levels_shot[path] = rel

func _tutorial_step() -> void:
	var step: Dictionary = A.TutorialManager._current_step()
	var ev: String = str(step.get("event", ""))
	if ev.is_empty():
		return
	var key := "tut:%s:%d" % [A.TutorialManager.active_id(), A.TutorialManager._step_index]
	if _tried.get(key, 0) > 20:
		return
	_tried[key] = _tried.get(key, 0) + 1
	A.TutorialManager.notify(ev)

func _interactables(level: Node) -> Array:
	var out := []
	for n in level.find_children("*", "Node2D", true, false):
		if n.has_signal("interacted") and n.has_method("try_interact") and not n.is_queued_for_deletion():
			out.append(n)
	return out

## How much an interactable looks like the next story step. -1 = can't be used.
func _score(ic: Node) -> int:
	var p: Node = ic.get_parent()
	if ic.get("disabled") or not p.is_visible_in_tree():
		return -1
	var GS = A.GameState
	var unlock = p.get("unlock_flag")
	if unlock != null and str(unlock) != "" and not GS.get_flag(unlock):
		return -1
	var cut = p.get("cutscene_id")
	var seen = p.get("cutscene_seen_flag")
	if seen == null:
		seen = p.get("seen_flag")
	if cut != null and str(cut) != "" and not GS.get_flag(str(seen)):
		return 100
	var ind = ic.get_node_or_null("Indicator")
	if ind != null and ind.visible:
		return 80
	var key = p.get("dialogue_scene_key")
	if key != null and str(key) != "":
		var sdf = str(p.get("story_done_flag"))
		if not A.ChapterLoader.get_scene_lines(str(p.get("dialogue_chapter")), str(key)).is_empty() and (sdf == "" or not GS.get_flag(sdf)):
			return 60
	return 0

func _act() -> void:
	var level := _level()
	var player := _player()
	if level == null or player == null:
		return
	# A level asking the player to walk somewhere (haboean_cafe.gd's directions
	# walk): go straight there, the way warps are taken below.
	if level.has_method("walk_goal"):
		var goal: Vector2i = level.walk_goal()
		if goal.x > -99:
			_p("WALK to the level's goal tile %s" % goal)
			player.global_position = level.global_position + Vector2(goal.x * 16, (goal.y + 1) * 16)
			return
	var GS = A.GameState
	if _jump_sunday and not GS.get_flag("chapter2_with_rose"):
		_jump_sunday = false
		var d: Dictionary = A.DayNightManager.get_date()
		var add: int = (6 - int(d["weekday"]) + 7) % 7
		var u: int = Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"], "hour": 12}) + add * 86400
		var nd: Dictionary = Time.get_datetime_dict_from_unix_time(u)
		A.DayNightManager.jump_to(nd["year"], nd["month"], nd["day"], 21.0)
		_p("TEST: fast calendar -> Saturday night %04d-%02d-%02d" % [nd.year, nd.month, nd.day])
		_want_sleep = true
	var lvl_path: String = GS.current_level_path
	var best: Node = null
	var best_score := 0
	var objects := []
	for ic in _interactables(level):
		var s := _score(ic)
		if s < 0:
			continue
		var key := "%s::%s" % [lvl_path, level.get_path_to(ic)]
		if s > 0:
			if _tried.get(key, 0) >= 2:
				continue
			if s > best_score:
				best_score = s
				best = ic
		elif not _touched_objects.has(key) and ic.get_parent().get("sleepable") == null:
			objects.append(ic)
	if best != null:
		_interact(best, level, "story score %d" % best_score)
		return
	if not objects.is_empty():
		_touched_objects["%s::%s" % [lvl_path, level.get_path_to(objects[0])]] = true
		_interact(objects[0], level, "coverage")
		return
	if _want_sleep or _explore_steps >= 8:
		for ic in _interactables(level):
			if ic.get_parent().get("sleepable") == true and _tried.get("bed:" + lvl_path, 0) < 1:
				_tried["bed:" + lvl_path] = 1
				_want_sleep = false
				_sleeps += 1
				_interact(ic, level, "sleep #%d" % _sleeps)
				return
	var warps := level.find_children("*", "Area2D", true, false).filter(func(w): return w.get("target_scene") != null)
	for w in warps:
		var wkey := "warpcheck:%s::%s" % [lvl_path, level.get_path_to(w)]
		if _touched_objects.has(wkey):
			continue
		_touched_objects[wkey] = true
		if str(w.target_scene) == "":
			_add_finding("error", "warp %s in %s has no target_scene (walking into it does nothing)" % [level.get_path_to(w), lvl_path.get_file()])
		elif not ResourceLoader.exists(w.target_scene):
			_add_finding("error", "warp %s in %s points at missing scene %s" % [level.get_path_to(w), lvl_path.get_file(), w.target_scene])
	warps = warps.filter(func(w): return str(w.target_scene) != "" and ResourceLoader.exists(w.target_scene))
	warps.sort_custom(func(a, b): return _warp_runs.get("%s::%s" % [lvl_path, level.get_path_to(a)], 0) < _warp_runs.get("%s::%s" % [lvl_path, level.get_path_to(b)], 0))
	for w in warps:
		if _explore_steps >= 14:
			break
		var key := "%s::%s" % [lvl_path, level.get_path_to(w)]
		if _tried.get("warp:" + key, 0) >= 2:
			continue
		_tried["warp:" + key] = _tried.get("warp:" + key, 0) + 1
		_warp_runs[key] = _warp_runs.get(key, 0) + 1
		_explore_steps += 1
		_p("WARP via %s -> %s #%s (needs flag '%s')" % [level.get_path_to(w), w.target_scene.get_file(), w.target_spawn_id, w.required_flag])
		player.global_position = w.global_position
		w._fire(player)
		return
	for ic in _interactables(level):
		if ic.get_parent().get("sleepable") == true and _tried.get("bed:" + lvl_path, 0) < 1:
			_tried["bed:" + lvl_path] = 1
			_sleeps += 1
			_interact(ic, level, "sleep #%d" % _sleeps)
			return
	_no_action_rounds += 1
	if _no_action_rounds == 1:
		_p("NOTHING TO DO: advancing clock 2h")
		A.DayNightManager.advance_minutes(120)
		_tried.clear(); _explore_steps = 0
		return
	if _no_action_rounds < 6:
		var bed_level: String = "res://scenes/world/chapter2/aklan_BR_Player.tscn" if GS.get_flag("seen_chapter2_scene0") \
			else "res://scenes/world/chapter1/us_bedroom.tscn"
		if lvl_path != bed_level:
			_p("NOTHING TO DO: going to bed in %s" % bed_level.get_file())
			A.MapManager.warp_to_scene(bed_level, "DefaultSpawn", 0)
			_want_sleep = true
			_tried.clear(); _explore_steps = 0
			return
		A.DayNightManager.advance_minutes(240)
		_tried.clear(); _explore_steps = 0
		_p("NOTHING TO DO: advancing clock 4h")
		return
	_add_finding("stuck", "auto-player found nothing left to do before chapter %d's finish line" % _current_chapter())
	_finish("no more actions found")

func _interact(ic: Node, level: Node, why: String) -> void:
	var key := "%s::%s" % [A.GameState.current_level_path, level.get_path_to(ic)]
	_tried[key] = _tried.get(key, 0) + 1
	var p: Node2D = ic.get_parent()
	var player := _player()
	_p("INTERACT %s (%s)" % [level.get_path_to(p), why])
	player.global_position = ((p.global_position + Vector2(0, 16)) / 16.0).round() * 16.0
	ic.interacted.emit(player)
