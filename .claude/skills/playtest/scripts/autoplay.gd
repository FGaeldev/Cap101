extends SceneTree
# Cap101 auto-player. Plays the real game by itself and records every error,
# warning and stall it hits, with a screenshot of the screen at that moment.
#
#   godot --path <project> --script autoplay.gd -- --mode=full --out=<dir>
#   godot --path <project> --script autoplay.gd -- --mode=chapter --chapter=2 --out=<dir>
#
# Options (after the bare "--"):
#   --mode=full|chapter|segment
#                         full: every available chapter in order from a new game.
#                         chapter: one chapter, starting from that chapter's start state.
#                         segment: one piece of the story (SEGMENTS), from its forced
#                         start state until the NEXT chapter's opening cutscene starts,
#                         so the handoff between chapters is played for real. run.sh
#                         "parallel" runs every segment, a few at once.
#   --chapter=N           chapter for --mode=chapter.
#   --segment=ID          segment for --mode=segment ("1", "2a", "2b", "3", "4").
#   --save-dir=DIR        read by GameState: saves go to DIR (user://playtest/...), never
#                         to the player's save slots. run.sh always passes one.
#   --out=DIR             where events.log, findings.json and shots/ go (required).
#   --budget=SEC          real-time limit (default 900 per chapter).
#   --speed=X             Engine.time_scale floor (default 3).
#   --wait-speed=X        Engine.time_scale while waiting for the clock (default 12).
#   --window=WxH          windowed at that size instead of fullscreen (e.g. 1600x720 = 20:9).
#
# It plays through real input, like a person: walks tile by tile by holding the
# ui_* actions along a grid path (walls and NPCs block it), faces what it wants
# and presses "interact", walks onto doors and holds their direction, advances
# dialogue with "interact", and clicks choice/menu buttons with the mouse. It
# never moves the player or the clock directly: time passes by waiting (sped up)
# or by sleeping in a bed it walked to. Minigames are still resolved without
# playing them, and tutorial steps it can't reach get their event sent.
#
# Must run WINDOWED (not --headless): screenshots need a real frame.
# Saves go to the --save-dir folder (GameState), so the player's slots are never touched.

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
	4: {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_ch4", "done": "_done_ch4"},
}

## Story segments for parallel runs. Each ends when the NEXT chapter's opening
## cutscene starts (the real handoff), except the last, which ends at its finish.
const SEGMENTS := {
	"1": {"start_level": "res://scenes/world/chapter1/us_bedroom.tscn", "setup": "_setup_ch1", "done": "_done_seg1"},
	"2a": {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_ch2", "done": "_done_seg2a"},
	"2b": {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_seg2b", "done": "_done_seg2b"},
	"3": {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_seg3", "done": "_done_seg3"},
	"4": {"start_level": "res://scenes/world/chapter2/aklan_living.tscn", "setup": "_setup_ch4", "done": "_done_ch4"},
}
## Cutscenes that have started this run (segment finish lines look here).
var _started_cutscenes := {}

var opts := {"mode": "full", "chapter": 1, "segment": "", "out": "", "budget": 0.0, "speed": 3.0, "wait_speed": 12.0}
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
var _want_bakhawan := false
var _bakhawan_went := false
var _mass_done := false
var _wait_until := -1

# navigation (real input)
const TILE := 16
const DIR_ACTIONS := {Vector2i.LEFT: "ui_left", Vector2i.RIGHT: "ui_right", Vector2i.UP: "ui_up", Vector2i.DOWN: "ui_down"}
const TRIGGER_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]  # comp_warp.gd TriggerDirection order
## Real ms a walk may stand still with input held (an NPC in the way) before replanning.
const STALL_MS := 1500
const MAX_REPLANS := 5
var _nav := {}               # active walk/interaction, see _nav_start
var _held := Vector2i.ZERO   # direction action currently held
var _scene_graph := {}       # level path -> [{node, to}] from every level's warps
var _failed_edges := {}      # "level::node" -> epoch it failed in
var _wait_hour := -1.0       # waiting for the clock to reach this hour (sped up)
var _waits := 0
var _bed_trips := 0
var _click := {}             # last button clicked: {key, t, btn}


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


## --window=WxH: play in a window of that size instead of the project's
## fullscreen, e.g. 1600x720 to test a 20:9 phone shape on a 16:9 monitor.
var _window_size := Vector2i.ZERO
var _hb_last := 0  # debug heartbeat (ticks ms)

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
			"segment": opts.segment = v
			"out": opts.out = v
			"budget": opts.budget = float(v)
			"speed": opts.speed = float(v)
			"wait-speed": opts.wait_speed = float(v)
			"window": _window_size = Vector2i(int(v.get_slice("x", 0)), int(v.get_slice("x", 1)))

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
	# Applied from the frame loop, not _initialize: the project's fullscreen
	# setting is applied after _initialize and would override it. Re-asserted
	# until it sticks.
	if _window_size.x > 0 and root.size != _window_size:
		root.mode = Window.MODE_WINDOWED
		root.size = _window_size
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
	if opts.mode == "segment":
		if not SEGMENTS.has(opts.segment):
			_add_finding("driver", "segment '%s' is not defined in autoplay.gd SEGMENTS" % opts.segment)
			_finish("segment not defined")
			return
		_chapters = [opts.segment]
	elif opts.mode == "chapter":
		if not CHAPTERS.has(opts.chapter):
			_p("END: chapter %d has no autoplay definition (playable: %s)" % [opts.chapter, playable])
			_add_finding("driver", "chapter %d is not playable yet / not defined in autoplay.gd CHAPTERS" % opts.chapter)
			_finish("chapter not defined")
			return
		_chapters = [opts.chapter]
	else:
		_chapters = playable
	if opts.budget <= 0.0:
		opts.budget = 2400.0 * _chapters.size()  # walking and sleeping take real time
	_build_scene_graph()
	if _headless:
		_p("WARNING: running headless -- no screenshots will be taken")
	_p("START mode=%s chapters=%s budget=%ds window=%s view=%s" % [opts.mode, _chapters, int(opts.budget), root.size, root.get_visible_rect().size])
	var GS = A.GameState
	GS.dev_mode = false
	GS.reset_game_state()
	GS.player_name = "Tester"
	GS.flag_changed.connect(_on_flag)
	A.QuestManager.quest_started.connect(func(q): _p("QUEST started " + q); _progress())
	A.QuestManager.quest_completed.connect(func(q): _p("QUEST completed " + q); _progress())
	A.CutsceneManager.cutscene_started.connect(func(c): _p("CUTSCENE start " + c); _started_cutscenes[c] = true)
	A.CutsceneManager.cutscene_finished.connect(func(c): _p("CUTSCENE end " + c))
	A.TutorialManager.tutorial_started.connect(func(t): _p("TUTORIAL start " + t))
	A.TutorialManager.tutorial_completed.connect(func(t): _p("TUTORIAL done " + t))
	A.DayNightManager.day_changed.connect(func(): _p("DAY -> %s" % str(A.DayNightManager.get_date())))
	# Chapter mode: force the state that chapter starts from.
	var first = _chapters[0]
	if opts.mode == "segment" or first != 1 or opts.mode == "chapter":
		call(_spec(first).setup)
		GS.current_level_path = _spec(first).start_level
	change_scene_to_file("res://scenes/Game.tscn")
	_phase = 1

func _current_chapter() -> Variant:
	return _chapters[_chapter_i] if _chapter_i < _chapters.size() else -1

## CHAPTERS entry, or SEGMENTS entry in segment mode.
func _spec(key: Variant) -> Dictionary:
	return SEGMENTS[key] if opts.mode == "segment" else CHAPTERS[key]

func _on_flag(flag: String, value: bool) -> void:
	_p("FLAG %s = %s" % [flag, value])
	_progress()
	if flag == "chapter2_mass_cathedral" and value:
		_want_bakhawan = true
		_mass_done = true  # the flag itself is cleared again once home
	if flag == "chapter2_going_bakhawan" and value:
		_bakhawan_went = true
	# A chapter just ended: its between-chapter goals (chapter_goals.gd) appear.
	if value and (flag == "chapter2_complete" or flag == "chapter3_complete"):
		_meet_chapter_goals()

func _progress() -> void:
	_epoch += 1
	_tried.clear()
	_no_action_rounds = 0
	_explore_steps = 0
	_waits = 0
	_bed_trips = 0

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

## Tour and Sunday mass done, and home again. (Rose only offers Bakhawan once
## Chapter 4 has started, so the trip isn't part of Chapter 2 any more.)
func _done_ch2() -> bool:
	var GS = A.GameState
	return GS.get_flag("chapter2_tour_done") and _mass_done \
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
	_meet_chapter_goals()

## Evening scene with Jonabel played.
func _done_ch3() -> bool:
	return A.GameState.get_flag("chapter3_complete") and not A.CutsceneManager.is_playing()

## The morning after Chapter 3 ended (weekday, 7:00), so Chapter 4's brief plays.
func _setup_ch4() -> void:
	_setup_ch3()
	var GS = A.GameState
	for f in ["chapter_card_chapter3_seen", "seen_chapter3_scene0", "chapter3_started", "seen_chapter3_scene1",
			"map_open_habuean", "seen_chapter3_scene2", "wove_first_row", "seen_chapter3_scene3",
			"got_pina_bookmark", "story_done_ch3_loleng", "seen_chapter3_scene4", "seen_chapter3_scene5",
			"chapter3_complete", "note_story_so_far_seen"]:
		GS.set_flag(f)
	for q in ["q006", "q007", "q008"]:
		A.QuestManager.complete_quest_silently(q)
	# The brief waits until chapters.json marks Chapter 4 out (NpcSchedule
	# "ch4_brief_pending"); treat it as out for this run so it can be tested first.
	_make_available("chapter4")

## Segment 1: Chapter 2's "home at last" opening has started.
func _done_seg1() -> bool:
	return _started_cutscenes.has("chapter2_scene0")

## Segment 2a: the first trip with Rose (tour) done and home again.
func _done_seg2a() -> bool:
	var GS = A.GameState
	return GS.get_flag("chapter2_tour_done") and not GS.get_flag("chapter2_with_rose") \
		and not A.CutsceneManager.is_playing()

## Segment 2b: home from the tour on a Saturday at 5 PM, so dinner plays, then
## Sunday mass the next morning, then a night's sleep ends Chapter 2.
func _setup_seg2b() -> void:
	_setup_ch2()
	var GS = A.GameState
	for f in ["chapter_card_chapter2_seen", "seen_chapter2_scene0", "chapter2_slept", "seen_chapter2_scene0b",
			"seen_chapter2_scene1", "seen_chapter2_scene2", "seen_chapter2_scene3", "seen_chapter2_scene4",
			"chapter2_tour_done", "map_open_market", "got_kalibo_map", "tutorial_ch2_map_done"]:
		GS.set_flag(f)
	for q in ["q011", "q012", "q013"]:
		A.QuestManager.complete_quest_silently(q)
	var DN = root.get_node("DayNightManager")
	while DN.get_date()["weekday"] != 6:
		GS.date_unix += 86400
	DN.set_hour(17.0)

## Segment 2b: Chapter 3's morning brief has started.
func _done_seg2b() -> bool:
	return _started_cutscenes.has("chapter3_scene0")

## Segment 3: Chapter 3, with Chapter 4 treated as out so its brief can start.
func _setup_seg3() -> void:
	_setup_ch3()
	_make_available("chapter4")

## Segment 3: Chapter 4's morning brief has started.
func _done_seg3() -> bool:
	return _started_cutscenes.has("chapter4_scene0")

## Shortcut, like resolving minigames: the between-chapter goals (family errands
## and Review tries, scripts/util/chapter_goals.gd) are met without playing the
## errands. The driver doesn't run errands; this keeps chapter handoffs testable.
func _meet_chapter_goals() -> void:
	for q in ["qs001", "qs003"]:
		var quest: Dictionary = A.QuestManager.quests.get(q, {})
		A.GameState.set_flag(str(quest.get("requires_flag", "")))
		A.QuestManager.complete_quest_silently(q)
	A.GameState.reviews_done = maxi(A.GameState.reviews_done, 6)
	_p("SHORTCUT chapter goals met (2 errands, 6 Review tries)")

## Marks a chapter available for this run only (its brief waits for chapters.json).
func _make_available(chapter_id: String) -> void:
	for ch in A.ChapterCard.get_chapters():
		if ch.get("id", "") == chapter_id:
			ch["available"] = true

## Evening scene with Jobert and Jonabel played.
func _done_ch4() -> bool:
	return A.GameState.get_flag("chapter4_complete") and not A.CutsceneManager.is_playing()

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
		_add_finding("stuck", "time budget (%ds) ran out before chapter %s finished" % [int(opts.budget), str(_current_chapter())])
		_finish("time budget reached")
		return
	if Engine.time_scale < opts.speed:
		Engine.time_scale = opts.speed
	if _game() == null:
		return
	if now - _hb_last > 5000:
		_hb_last = now
		_p("HB cap=%s q=%d nav=%d wait_h=%.1f card=%s book=%s dlg=%s cut=%s warp=%s win=%s view=%s" % [
			_capturing, _shot_queue.size(), _nav.size(), _wait_hour, A.ChapterCard.visible,
			A.BookUI.visible, A.DialogueUI.is_active(), A.CutsceneManager.is_playing(),
			A.MapManager.is_transitioning, root.size, root.get_visible_rect().size])
	# Hold still while a finding's screenshot is pending, so it shows that moment.
	if _capturing or not _shot_queue.is_empty():
		_hold_dir(Vector2i.ZERO)  # stop where we are; the walk picks up again after
		return
	# Chapter finished?
	if _chapter_i < _chapters.size() and call(_spec(_chapters[_chapter_i]).done):
		_p("CHAPTER %s COMPLETE" % str(_chapters[_chapter_i]))
		_chapter_i += 1
		if _chapter_i >= _chapters.size():
			_finish("all requested chapters played")
			return
	var lvl_path: String = A.GameState.current_level_path
	if lvl_path != _last_level:
		_last_level = lvl_path
		_p("LEVEL " + lvl_path)
	_check_click_miss()
	if not _nav.is_empty() and _nav_interrupted():
		return
	if _wait_hour >= 0.0 and (A.CutsceneManager.is_playing() or A.DialogueUI.is_active() or A.MapManager.is_transitioning):
		_stop_waiting("something happened")
	if A.ChapterCard.visible:
		if not A.ChapterCard._continue_btn.disabled:
			if _wait(300):
				return
			_p("CHAPTER CARD: " + A.ChapterCard._title_label.text + " -> click Continue")
			_click_button(A.ChapterCard._continue_btn, "chapter_card")
		return
	if A.BookUI.visible:
		if A.TutorialManager.is_running():
			_tutorial_step()
		if _wait(400):
			return
		_p("BOOKUI close (Esc)")
		_key(KEY_ESCAPE)
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
		_p("NEWSPAPER put down (Esc)")
		_key(KEY_ESCAPE)
		return
	if DUI._npc_menu != null and is_instance_valid(DUI._npc_menu) and DUI._npc_menu.visible:
		if _wait(300):
			return
		var pick := "Talk"
		if _review_done < 2 and A.GameState.get_flag("seen_chapter1_scene4"):
			pick = "Review"
		var who: String = DUI._npc_menu.get_node("NpcName").text if DUI._npc_menu.has_node("NpcName") else "?"
		var btn: Button = null
		for b in DUI._npc_menu.get_children():
			if b is Button and b.text == pick:
				btn = b
		if btn == null:
			_add_finding("softlock", "NPC menu for %s has no '%s' button" % [who, pick])
			DUI._on_npc_interaction_choice(pick.to_lower())
			return
		if pick == "Review" and _click.get("key", "") != "npc:" + who:
			_review_done += 1
		_p("NPC MENU (%s) -> click %s" % [who, pick])
		_click_button(btn, "npc:" + who)
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
		# Clicked this same menu a moment ago and it's still up: the click missed.
		if _click.get("key", "") == key and Time.get_ticks_msec() - int(_click.get("t", 0)) < 1500:
			return
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
		_p("CHOICE [%s] -> click '%s'  (options: %s)" % [prompt.left(70), btns[idx].text, " / ".join(btns.map(func(b): return b.text.left(30)))])
		_click_button(btns[idx], key)
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
		_tap_action("interact")  # same as the keyboard; DialogueBox finishes typing, then advances
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
	if not _nav.is_empty():
		_nav_tick()
		return
	if _wait_hour >= 0.0:
		_wait_tick()
		return
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
		# Door interact boxes (comp_warp.gd) are reached through the warp route instead.
		if n.name == "DoorInteract" and n.get_parent().get("target_scene") != null:
			continue
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

var _route_target := ""      # level the auto-player is walking to through doors
var _block_cache := {}

## Picks the next thing to do and starts walking to it. Called once the game has
## been idle a moment (no dialogue, cutscene or transition).
func _act() -> void:
	var level := _level()
	var player := _player()
	if level == null or player == null:
		return
	var GS = A.GameState
	var lvl_path: String = GS.current_level_path
	# Standing between tiles: grid walking (walk_state.gd) keeps the offset for good,
	# so doors and objects stop lining up. Something moved the player off the grid.
	if not player.has_meta("pew") and player.global_position.distance_to(_cell_pos(_cell_of(player.global_position))) > 0.5:
		_add_finding("off_grid", "player left standing between tiles at %s in %s (grid walking keeps that offset, so doors and objects stop lining up)" % [player.global_position, lvl_path.get_file()])
	# Seated (pew.gd, seat.gd): any direction gets up, like on a phone.
	if player.has_meta("pew"):
		_p("STAND UP (press down)")
		_hold_dir(Vector2i.DOWN)
		_nav = {"kind": "stand", "phase": "tap", "ticks": 0}
		return
	# A level asking the player to walk somewhere (haboean_cafe.gd's directions walk).
	if level.has_method("walk_goal"):
		var goal: Vector2i = level.walk_goal()
		if goal.x > -99:
			var off := Vector2i((level.global_position / TILE).round())
			if _tried.get("goal:%s" % goal, 0) < 3:
				_tried["goal:%s" % goal] = _tried.get("goal:%s" % goal, 0) + 1
				if _nav_start({"kind": "goal", "goals": {goal + off: true}, "why": "level goal tile %s" % goal, "name": "goal"}):
					return
	# Walking through doors to a room picked earlier (e.g. to bed).
	if _route_target != "":
		if lvl_path == _route_target:
			_p("ROUTE arrived in " + lvl_path.get_file())
			_route_target = ""
		else:
			var edge := _route_edge(lvl_path, _route_target)
			var w: Node = level.get_node_or_null(NodePath(edge.get("node", ""))) if not edge.is_empty() else null
			if w != null:
				_nav_warp(w, level, "route to " + _route_target.get_file())
				return
			_p("ROUTE lost: no known door path from %s to %s" % [lvl_path.get_file(), _route_target.get_file()])
			_route_target = ""
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
		_nav_interact(best, level, "story score %d" % best_score, best_score)
		return
	if not objects.is_empty():
		_touched_objects["%s::%s" % [lvl_path, level.get_path_to(objects[0])]] = true
		_nav_interact(objects[0], level, "coverage", 0)
		return
	if _want_sleep or _explore_steps >= 8:
		for ic in _interactables(level):
			if ic.get_parent().get("sleepable") == true and _tried.get("bed:" + lvl_path, 0) < 1:
				_tried["bed:" + lvl_path] = 1
				_want_sleep = false
				_sleeps += 1
				_nav_interact(ic, level, "sleep #%d" % _sleeps, 0)
				return
	var warps := level.find_children("*", "Area2D", true, false).filter(func(w): return w.get("target_scene") != null)
	for w in warps:
		var wkey := "warpcheck:%s::%s" % [lvl_path, level.get_path_to(w)]
		if _touched_objects.has(wkey):
			continue
		_touched_objects[wkey] = true
		if str(w.target_scene) == "":
			# closed_message = closed on purpose (comp_warp.gd): a wall with a remark.
			if str(w.get("closed_message")).is_empty():
				_add_finding("error", "warp %s in %s has no target_scene and no closed_message" % [level.get_path_to(w), lvl_path.get_file()])
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
		_nav_warp(w, level, "explore")
		return
	for ic in _interactables(level):
		if ic.get_parent().get("sleepable") == true and _tried.get("bed:" + lvl_path, 0) < 1:
			_tried["bed:" + lvl_path] = 1
			_sleeps += 1
			_nav_interact(ic, level, "sleep #%d" % _sleeps, 0)
			return
	# Nothing left here: let the clock run (sped up), or walk to bed and sleep.
	_no_action_rounds += 1
	var hour: float = A.DayNightManager.get_hour()
	if _waits < 4 and hour >= 6.0 and hour < 19.0:
		_waits += 1
		_tried.clear(); _explore_steps = 0
		_start_waiting(minf(hour + 2.0, 19.5), "nothing to do")
		return
	if _bed_trips < 7:
		_bed_trips += 1
		_waits = 0
		_want_sleep = true
		_tried.clear(); _explore_steps = 0
		var bed_level: String = "res://scenes/world/chapter2/aklan_BR_Player.tscn" if GS.get_flag("seen_chapter2_scene0") \
			else "res://scenes/world/chapter1/us_bedroom.tscn"
		if lvl_path != bed_level:
			_p("NOTHING TO DO: walking to bed in %s" % bed_level.get_file())
			_route_target = bed_level
		return
	_add_finding("stuck", "auto-player found nothing left to do before chapter %s's finish line" % str(_current_chapter()))
	_finish("no more actions found")

# --- navigation: real input ------------------------------------------------------

func _nav_interact(ic: Node, level: Node, why: String, score: int) -> void:
	var key := "%s::%s" % [A.GameState.current_level_path, level.get_path_to(ic)]
	_tried[key] = _tried.get(key, 0) + 1
	var p: Node2D = ic.get_parent()
	var rect := _shape_rect(ic.get_node_or_null("InteractArea/CollisionShape2D"))
	if not rect.has_area():
		rect = Rect2(p.global_position + Vector2(-2, -18), Vector2(20, 20))
	var name := str(level.get_path_to(p))
	_p("GO INTERACT %s (%s)" % [name, why])
	_nav_start({"kind": "interact", "ic": ic, "rect": rect, "why": why, "name": name, "score": score})

func _nav_warp(w: Node, level: Node, why: String) -> void:
	var trig: Vector2i = TRIGGER_DIRS[int(w.trigger_direction)]
	var name := str(level.get_path_to(w))
	_p("GO WARP %s -> %s #%s (%s, needs flag '%s')" % [name, str(w.target_scene).get_file(), w.target_spawn_id, why, w.required_flag])
	_nav_start({"kind": "warp", "warp": w, "rect": _shape_rect(w.get_node_or_null("CollisionShape2D")),
		"trig": trig, "why": why, "name": name, "edge": "%s::%s" % [A.GameState.current_level_path, name]})

## Plans a path to the target's tiles and starts walking. False if it can't be reached.
func _nav_start(nav: Dictionary) -> bool:
	var player := _player()
	_block_cache.clear()
	var start := _cell_of(player.global_position)
	var goals: Dictionary = nav.get("goals", {})
	if goals.is_empty():
		goals = _goal_cells(nav.rect, start, nav.get("trig", Vector2i.ZERO))
	nav.goals = goals
	nav.avoid = _other_warp_cells(nav.get("warp"))
	var path = _find_path(start, goals, nav.avoid)
	if path == null:
		_nav_unreachable(nav)
		return false
	nav.path = path
	nav.phase = "walk"
	nav.replans = 0
	nav.prev = player.global_position
	nav.still_since = -1
	nav.face_tries = 0
	nav.t = Time.get_ticks_msec()
	_nav = nav
	_p("WALK %d tiles to %s" % [path.size(), nav.name])
	return true

func _nav_unreachable(nav: Dictionary) -> void:
	var lvl: String = A.GameState.current_level_path.get_file()
	var player := _player()
	var start := _cell_of(player.global_position)
	var around := []
	for d in TRIGGER_DIRS:
		around.append("%s:%s" % [DIR_ACTIONS[d].trim_prefix("ui_"), _blocker_names(start + d)])
	_p("UNREACHABLE %s in %s (%d candidate tiles %s) from tile %s pos %s; around: %s" % [nav.get("name", "?"), lvl, nav.get("goals", {}).size(), nav.get("goals", {}).keys().slice(0, 4), start, player.global_position, ", ".join(around)])
	if nav.kind == "warp":
		_failed_edges[nav.edge] = _epoch
	if nav.kind == "interact" and int(nav.get("score", 0)) > 0:
		# Only the map's fault if it's unreachable even with every NPC out of the way.
		_ignore_npcs = true
		_block_cache.clear()
		var walled: bool = _find_path(start, _goal_cells(nav.rect, start, Vector2i.ZERO), {}) == null
		_ignore_npcs = false
		_block_cache.clear()
		if walled:
			_add_finding("stuck", "can't walk to %s in %s: no tile where it can be used is reachable, even with NPCs out of the way" % [nav.name, lvl])
		else:
			_p("  (an NPC is in the way right now)")
	_nav = {}

func _nav_clear() -> void:
	_hold_dir(Vector2i.ZERO)
	_nav = {}
	_block_cache.clear()

## True (and the walk is over) once something took over the screen: dialogue, a
## cutscene, a warp, the Book. Expected when we just interacted or held a door.
func _nav_interrupted() -> bool:
	var why := ""
	if A.CutsceneManager.is_playing():
		why = "cutscene"
	elif A.MapManager.is_transitioning:
		why = "warp"
	elif A.DialogueUI.is_active():
		why = "dialogue/menu"
	elif A.BookUI.visible:
		why = "book"
	elif A.ChapterCard.visible:
		why = "chapter card"
	elif _nav.get("phase", "") == "await" and _player() != null and _player().has_meta("pew"):
		why = "sat down"
	if why == "":
		return false
	if _nav.get("phase", "") in ["await", "hold"]:
		_p("  -> %s" % why)
	else:
		_p("WALK to %s interrupted by %s" % [_nav.get("name", "?"), why])
	_nav_clear()
	return true

func _nav_tick() -> void:
	var player := _player()
	if player == null:
		_nav_clear()
		return
	var now := Time.get_ticks_msec()
	match _nav.phase:
		"tap":
			_nav.ticks += 1
			if _nav.ticks >= 2:
				_nav_clear()
		"walk":
			_walk_tick(player, now)
		"face":
			var want := _face_dir(player)
			if want == Vector2i.ZERO or Vector2i(player.facing_vec) == want or _nav.face_tries >= 3:
				_nav.phase = "act"
				return
			_hold_dir(want)  # one frame: Idle turns in place (idle_state.gd TURN_DELAY)
			_nav.face_tries += 1
			_nav.phase = "face_release"
		"face_release":
			_hold_dir(Vector2i.ZERO)
			_nav.phase = "face"
		"act":
			if _nav.kind == "goal":
				_p("  reached the goal tile")
				_nav_clear()
			elif _nav.kind == "warp":
				var door: Node = _nav.get("warp")
				if is_instance_valid(door) and door.has_method("uses_button") and door.uses_button():
					# Doors open with the interact button (comp_warp.gd entry) while the
					# player faces into them: turn toward the door, then press (in "hold").
					_hold_dir(_nav.trig)
				else:
					_hold_dir(_nav.trig)
				_nav.phase = "hold"
				_nav.t = now
			else:
				_act_interact(player, now)
		"wait_range":
			_act_interact(player, now)
		"await":
			if now - int(_nav.t) > 1500:
				_p("  (no visible response from %s)" % _nav.name)
				_nav_clear()
		"hold":
			var held_door: Node = _nav.get("warp")
			if is_instance_valid(held_door) and held_door.has_method("uses_button") and held_door.uses_button():
				var dic: Node = held_door.get_node_or_null("DoorInteract")
				if now - int(_nav.t) > 250:
					_hold_dir(Vector2i.ZERO)  # facing into the door now; let go and press
					if dic != null:
						dic.try_interact()
			if now - int(_nav.t) > 3000:
				_add_finding("stuck", "stood on door %s in %s holding %s for 3s and it didn't open" % [_nav.name, A.GameState.current_level_path.get_file(), DIR_ACTIONS[_nav.trig]])
				_failed_edges[_nav.edge] = _epoch
				_nav_clear()

func _act_interact(player: Node2D, now: int) -> void:
	# Untyped first: assigning a freed NPC (left on its schedule) to a typed var errors
	# before the validity check can run.
	var target = _nav.get("ic")
	if not is_instance_valid(target):
		_p("  (target gone: %s)" % _nav.get("name", "?"))
		_nav_clear()
		return
	var ic: Node = target
	if not ic._in_range:
		if _nav.phase != "wait_range":
			_nav.phase = "wait_range"
			_nav.t = now
			return
		if now - int(_nav.t) < 600:
			return
		var c := _cell_of(player.global_position)
		var area: Area2D = ic.get_node_or_null("InteractArea")
		if area == null or not area.monitoring or not _reaches(_body_rect(c), _nav.rect):
			_p("  %s isn't usable right now (area off or out of reach)" % _nav.name)
			_nav_clear()
			return
		_p("  next to %s but its interact area doesn't reach the player: player tile %s pos %s, area %s, body rect overlap %s, overlapping bodies %s" % [
			_nav.name, c, player.global_position, _nav.rect, _body_rect(c).intersection(_nav.rect),
			area.get_overlapping_bodies().map(func(b): return b.name) if area and area.monitoring else []])
		# A person would shuffle to another side; try the remaining tiles first.
		_nav.goals.erase(c)
		_nav.tried_tiles = int(_nav.get("tried_tiles", 0)) + 1
		if not _nav.goals.is_empty() and _nav.tried_tiles < 4:
			var path = _find_path(c, _nav.goals, _nav.avoid)
			if path != null:
				_p("  trying another side (%d tiles)" % path.size())
				_nav.path = path
				_nav.phase = "walk"
				_nav.face_tries = 0
				_nav.still_since = -1
				return
		if ic.get_parent() is CharacterBody2D:
			_p("  (%s moved away)" % _nav.name)
			_nav_clear()
			return
		_add_finding("interact_range", "walked up to %s in %s (tile %s) and it can't be used from there: its interact area doesn't reach any tile the player can stand on" % [_nav.name, A.GameState.current_level_path.get_file(), c])
		_nav_clear()
		return
	var nearest = ic.get_nearest_to(player)
	if nearest != ic and nearest != null:
		var other := str(_level().get_path_to(nearest.get_parent())) if _level() else "?"
		var aim: Vector2 = player.global_position + Vector2(8, -8) + player.facing_vec.normalized() * 16.0
		var cands := []
		for cand in ic._in_range_pool:
			if is_instance_valid(cand):
				cands.append("%s %.1f" % [cand.get_parent().name, cand.box_center().distance_to(aim)])
		_p("  interact picks %s, not %s: player %s facing %s, distances from the faced spot: %s" % [other, _nav.name, _cell_of(player.global_position), player.facing_vec, ", ".join(cands)])
		_add_finding("interact_target", "facing %s from the next tile in %s, but interact picks %s instead" % [_nav.name, A.GameState.current_level_path.get_file(), other])
	_p("  press interact (facing %s)" % player.direction)
	_tap_action("interact")
	_nav.phase = "await"
	_nav.t = now

## Follows the planned path by holding direction actions. The next direction is
## set while a step is still under way, since walk_state.gd chains the next step
## from the input held when the current one ends.
func _walk_tick(player: Node2D, now: int) -> void:
	var pos: Vector2 = player.global_position
	var moved: Vector2 = pos - _nav.prev
	_nav.prev = pos
	# Watchdogs: not moving at all for a while (wherever it stands), or a walk
	# that takes far too long, gets replanned / dropped instead of hanging.
	if moved.length() >= 0.01 or not _nav.has("last_move"):
		_nav.last_move = now
	elif now - int(_nav.last_move) > STALL_MS * 2:
		_nav.last_move = now
		_replan(player, "not moving at %s (%s), holding %s, state %s" % [pos, _cell_of(pos), DIR_ACTIONS.get(_held, "nothing"), player.state_machine.current_state.name if player.get("state_machine") and player.state_machine.get("current_state") else "?"])
		return
	if now - int(_nav.t) > 45000:
		_p("WALK to %s took over 45s, giving up" % _nav.name)
		_nav_clear()
		return
	var path: Array = _nav.path
	if path.is_empty():
		_hold_dir(Vector2i.ZERO)
		_nav.phase = "face"
		return
	var cell := _cell_of(pos)
	var on_grid := pos.distance_to(_cell_pos(cell)) < 0.05
	if on_grid:
		if _nav.goals.has(cell):
			_hold_dir(Vector2i.ZERO)
			if moved.length() < 0.01:
				_nav.phase = "face"
			return
		var idx := path.find(cell)
		var next_i := idx + 1 if idx >= 0 else 0
		var want: Vector2i = path[next_i] - cell if next_i < path.size() else Vector2i.ZERO
		if absi(want.x) + absi(want.y) != 1:
			_replan(player, "off the path at %s" % cell)
			return
		_hold_dir(want)
		if moved.length() < 0.01:
			if _nav.still_since < 0:
				_nav.still_since = now
			elif now - int(_nav.still_since) > STALL_MS:
				_replan(player, "blocked at %s heading %s" % [cell, DIR_ACTIONS[want]])
		else:
			_nav.still_since = -1
		return
	_nav.still_since = -1
	var dir := Vector2i(signi(roundi(moved.x * 100)), signi(roundi(moved.y * 100)))
	if dir == Vector2i.ZERO:
		dir = _held
	var to := cell
	if dir.x > 0: to.x = floori(pos.x / TILE) + 1
	elif dir.x < 0: to.x = ceili(pos.x / TILE) - 1
	if dir.y > 0: to.y = floori(pos.y / TILE)
	elif dir.y < 0: to.y = ceili(pos.y / TILE) - 2
	if _nav.goals.has(to):
		_hold_dir(Vector2i.ZERO)  # stop on the goal
		return
	var hi := path.find(to)
	if hi < 0 or hi + 1 >= path.size():
		_hold_dir(Vector2i.ZERO)  # stepping off the path: stop, replan when still
		return
	_hold_dir(path[hi + 1] - to)

func _replan(player: Node2D, why: String) -> void:
	_nav.replans += 1
	_hold_dir(Vector2i.ZERO)
	if _nav.replans > MAX_REPLANS:
		_p("WALK to %s gave up (%s)" % [_nav.name, why])
		if _nav.kind == "warp":
			_failed_edges[_nav.edge] = _epoch
		_nav_clear()
		return
	_block_cache.clear()
	var path = _find_path(_cell_of(player.global_position), _nav.goals, _nav.avoid)
	if path == null:
		_nav_unreachable(_nav)
		_hold_dir(Vector2i.ZERO)
		return
	_p("  replan (%s): %d tiles" % [why, path.size()])
	_nav.path = path
	_nav.still_since = -1

## Direction from the player's tile toward the target's centre, on its longer axis.
func _face_dir(player: Node2D) -> Vector2i:
	if not _nav.has("rect"):
		return Vector2i.ZERO
	var d: Vector2 = (_nav.rect as Rect2).get_center() - (player.global_position + Vector2(8, -8))
	if d.length() < 4.0:
		return Vector2i.ZERO
	if absf(d.x) > absf(d.y):
		return Vector2i(signi(int(signf(d.x))), 0)
	return Vector2i(0, signi(int(signf(d.y))))

# --- grid ----------------------------------------------------------------------

## Tile of an actor origin (bottom-left corner of its tile, like every actor here).
func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / TILE), roundi(pos.y / TILE) - 1)

func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, (c.y + 1) * TILE)

## The player's 14x14 body on tile c (Player.tscn's CollisionShape2D).
func _body_rect(c: Vector2i) -> Rect2:
	return Rect2(c.x * TILE + 1, c.y * TILE + 1, 14, 14)

## Positive overlap both ways. NPC areas (20x20 on their tile) reach a
## neighbouring tile by exactly 1 px, which usually registers.
func _reaches(body: Rect2, area: Rect2) -> bool:
	var i := body.intersection(area)
	return i.size.x > 0.5 and i.size.y > 0.5

## What fills tile c, for the log: collider names, or "free".
func _blocker_names(c: Vector2i) -> String:
	var player := _player()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, Vector2(c.x * TILE + 8, c.y * TILE + 8))
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	var names := []
	for hit in player.get_world_2d().direct_space_state.intersect_shape(q, 4):
		names.append(str(hit["collider"].name))
	if names.is_empty():
		return "out of map bounds" if _blocked(c) else "free"
	return "/".join(names)

func _shape_rect(cs: Node) -> Rect2:
	if cs == null or not cs is CollisionShape2D or not cs.shape is RectangleShape2D:
		return Rect2()
	var size: Vector2 = (cs.shape as RectangleShape2D).size * (cs as Node2D).global_transform.get_scale().abs()
	return Rect2((cs as Node2D).global_position - size / 2.0, size)

## Free tiles where the player's body overlaps `rect`. For a door set into a wall,
## the tiles in front of it from which a step toward `trig` reaches it.
func _goal_cells(rect: Rect2, start: Vector2i, trig: Vector2i) -> Dictionary:
	var out := {}
	if not rect.has_area():
		return out
	var r := rect.grow(TILE)
	for cx in range(floori(r.position.x / TILE), ceili(r.end.x / TILE) + 1):
		for cy in range(floori(r.position.y / TILE), ceili(r.end.y / TILE) + 1):
			var c := Vector2i(cx, cy)
			if _reaches(_body_rect(c), rect) and (c == start or not _blocked(c)):
				out[c] = true
	# Like a person, line up with the target: keep only tiles straight in front of
	# it (its centre within half a tile on the other axis), when there are any.
	var centre := rect.get_center()
	var lined := {}
	for c: Vector2i in out:
		var d: Vector2 = centre - Vector2(c.x * TILE + 8, c.y * TILE + 8)
		if absf(d.x) < TILE / 2.0 or absf(d.y) < TILE / 2.0:
			lined[c] = true
	if not lined.is_empty():
		out = lined
	if out.is_empty() and trig != Vector2i.ZERO:
		for cx in range(floori(r.position.x / TILE) - 1, ceili(r.end.x / TILE) + 2):
			for cy in range(floori(r.position.y / TILE) - 1, ceili(r.end.y / TILE) + 2):
				var c := Vector2i(cx, cy)
				if _reaches(_body_rect(c + trig), rect) and (c == start or not _blocked(c)):
					out[c] = true
	return out

## Tiles on other doors, which a careful player walks around.
func _other_warp_cells(target: Variant) -> Dictionary:
	var out := {}
	var level := _level()
	if level == null:
		return out
	for w in level.find_children("*", "Area2D", true, false):
		if w == target or w.get("target_scene") == null:
			continue
		var rect := _shape_rect(w.get_node_or_null("CollisionShape2D"))
		if not rect.has_area():
			continue
		for cx in range(floori(rect.position.x / TILE) - 1, ceili(rect.end.x / TILE) + 1):
			for cy in range(floori(rect.position.y / TILE) - 1, ceili(rect.end.y / TILE) + 1):
				if _body_rect(Vector2i(cx, cy)).intersects(rect):
					out[Vector2i(cx, cy)] = true
	return out

## Something the player can't walk into fills tile c: walls, furniture, NPCs.
## Same test as walk_state.gd's test_move, as a shape query on the player's mask.
## With _ignore_npcs set, characters don't count (to tell "an NPC is in the way
## right now" from "the map itself walls it off").
var _ignore_npcs := false

func _blocked(c: Vector2i) -> bool:
	if _block_cache.has(c):
		return _block_cache[c]
	var player := _player()
	var hit := false
	var g := _game()
	var bounds = g.get("_map_bounds") if g else null
	if bounds is Rect2 and (bounds as Rect2).has_area() and not (bounds as Rect2).grow(TILE).has_point(Vector2(c.x * TILE + 8, c.y * TILE + 8)):
		hit = true
	else:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(14, 14)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(0.0, Vector2(c.x * TILE + 8, c.y * TILE + 8))
		q.collision_mask = player.collision_mask
		q.exclude = [player.get_rid()]
		for h in player.get_world_2d().direct_space_state.intersect_shape(q, 4):
			if not (_ignore_npcs and h["collider"] is CharacterBody2D):
				hit = true
	_block_cache[c] = hit
	return hit

## Breadth-first grid path from start to the nearest goal tile, not counting start.
## [] if start is a goal, null if no goal can be reached. Walks around `avoid`
## (other doors) when it can, and across them when that's the only way.
func _find_path(start: Vector2i, goals: Dictionary, avoid: Dictionary) -> Variant:
	var path = _bfs(start, goals, avoid)
	if path == null and not avoid.is_empty():
		path = _bfs(start, goals, {})
	return path

func _bfs(start: Vector2i, goals: Dictionary, avoid: Dictionary) -> Variant:
	if goals.is_empty():
		return null
	if goals.has(start):
		return []
	var came := {start: start}
	var q: Array[Vector2i] = [start]
	var found := false
	var end := start
	while not q.is_empty() and came.size() < 8000:
		var c: Vector2i = q.pop_front()
		if goals.has(c):
			found = true
			end = c
			break
		for d in TRIGGER_DIRS:
			var n: Vector2i = c + d
			if came.has(n) or _blocked(n) or (avoid.has(n) and not goals.has(n)):
				continue
			came[n] = c
			q.append(n)
	if not found:
		return null
	var path: Array = []
	var cur := end
	while cur != start:
		path.push_front(cur)
		cur = came[cur]
	return path

# --- doors between levels ------------------------------------------------------

## Every level's doors, read from the scene files: level -> [{node, to}].
func _build_scene_graph() -> void:
	var files: Array = []
	_list_scenes("res://scenes/world", files)
	for f in files:
		var ps = load(f)
		if not ps is PackedScene:
			continue
		var st: SceneState = ps.get_state()
		var edges: Array = []
		for i in st.get_node_count():
			for j in st.get_node_property_count(i):
				if st.get_node_property_name(i, j) == "target_scene":
					var to := str(st.get_node_property_value(i, j))
					if to != "":
						edges.append({"node": str(st.get_node_path(i)), "to": to})
		_scene_graph[f] = edges
	_p("door graph: %d levels" % _scene_graph.size())

func _list_scenes(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		if not sub.begins_with("_"):
			_list_scenes(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir.path_join(f))

## First door to take from `from` toward `to`, skipping doors that failed this epoch.
func _route_edge(from: String, to: String) -> Dictionary:
	var prev := {from: {}}
	var q: Array = [from]
	while not q.is_empty():
		var s: String = q.pop_front()
		if s == to:
			break
		for e in _scene_graph.get(s, []):
			if _failed_edges.get("%s::%s" % [s, e.node.trim_prefix("./")], -1) == _epoch or prev.has(e.to):
				continue
			prev[e.to] = {"from": s, "edge": e}
			q.append(e.to)
	if to == from or not prev.has(to):
		return {}
	var cur := to
	while prev[cur]["from"] != from:
		cur = prev[cur]["from"]
	return prev[cur]["edge"]

# --- input ---------------------------------------------------------------------

## Holds one direction action (the keyboard arrows / joystick), releasing the last.
func _hold_dir(d: Vector2i) -> void:
	if d == _held:
		return
	if _held != Vector2i.ZERO:
		Input.action_release(DIR_ACTIONS[_held])
	if d != Vector2i.ZERO:
		Input.action_press(DIR_ACTIONS[d])
	_held = d

## One press and release of an action, as an input event (reaches _unhandled_input).
func _tap_action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)

func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = keycode
		e.physical_keycode = keycode
		e.pressed = pressed
		Input.parse_input_event(e)

## Left click at the centre of a button, in window coordinates, the way a mouse
## (or, with emulate_touch_from_mouse, a finger) would.
func _click_button(btn: Control, key: String) -> void:
	var vp_pos: Vector2 = btn.get_global_transform_with_canvas() * (btn.size / 2.0)
	var win_pos: Vector2 = root.get_screen_transform() * vp_pos
	var motion := InputEventMouseMotion.new()
	motion.position = win_pos
	motion.global_position = win_pos
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = win_pos
		e.global_position = win_pos
		Input.parse_input_event(e)
	_click = {"key": key, "t": Time.get_ticks_msec(), "btn": btn}

## A clicked button still up 1.5 s later didn't take the click: report it, then
## press it directly so the run goes on.
func _check_click_miss() -> void:
	if _click.is_empty():
		return
	var btn = _click.btn
	if not is_instance_valid(btn) or not btn.is_visible_in_tree():
		_click = {}
		return
	if Time.get_ticks_msec() - int(_click.t) < 1500:
		return
	_add_finding("click_miss", "clicked the middle of '%s' (%s) and nothing happened; pressed it directly" % [btn.get("text"), str(_click.key).left(60)])
	_click = {}
	btn.pressed.emit()

# --- waiting for the clock -----------------------------------------------------

func _start_waiting(hour: float, why: String) -> void:
	_wait_hour = hour
	Engine.time_scale = opts.wait_speed
	_p("WAIT until %.1fh (%s), game speed x%s" % [hour, why, opts.wait_speed])

func _wait_tick() -> void:
	var h: float = A.DayNightManager.get_hour()
	if h >= _wait_hour or h < 5.0:
		_stop_waiting("clock reached %.1fh" % h)

func _stop_waiting(why: String) -> void:
	_wait_hour = -1.0
	Engine.time_scale = opts.speed
	_p("  stop waiting (%s)" % why)
