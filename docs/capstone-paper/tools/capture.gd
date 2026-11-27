extends SceneTree
# Captures screenshots of AkeanQuest's main screens for the capstone paper.
#   godot --path <project> --script capture.gd -- --save-dir=user://playtest/capture/ --out=<dir>
# Windowed only. Saves go to --save-dir, never the player's slots.

var out := ""
## --only-pastrana: retake 02_world_pastrana alone, then quit.
var only_pastrana := false
## 02_world_pastrana: the player stands on the path just south of the WWII obelisk
## and the camera is nudged up, so the obelisk with Martelino and Mijares is fully
## in frame, right of the quest panel.
const PASTRANA_SHOT_POS := Vector2(632, 864)
const PASTRANA_CAM_OFFSET := Vector2(-16, -62)
var A := {}
var started := false
var log_lines: Array[String] = []

func _initialize() -> void:
	auto_accept_quit = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--only-pastrana":
			only_pastrana = true

func _process(_d: float) -> bool:
	if not started:
		started = true
		_run()
	# Keep tutorial bubbles out of the shots.
	var tm = root.get_node_or_null("TutorialManager")
	if tm and "visible" in tm:
		tm.visible = false
	# Side-quest rows (Kalibo goals) would cover half of every shot. The HUD sets
	# .visible every frame, so fade them out instead.
	var sq = root.get_node_or_null("Game/UILayer/HUD/QuestColumn/SubQuests")
	if sq:
		sq.modulate.a = 0.0
	return false

func _p(s: String) -> void:
	print("[capture] " + s)
	log_lines.append(s)

func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _shot(name: String) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	_p("shot " + name)

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _find_line(chapter: int, pred: Callable) -> Dictionary:
	var d = _json("res://data/dialogue/chapter%d.json" % chapter)
	var found := {}
	var stack: Array = [d]
	while not stack.is_empty() and found.is_empty():
		var v = stack.pop_back()
		if v is Dictionary:
			if pred.call(v):
				found = v
				break
			for k in v:
				stack.append(v[k])
		elif v is Array:
			for i in range(v.size() - 1, -1, -1):
				stack.append(v[i])
	return found

func _cleanup() -> void:
	var D = A.DialogueUI
	for key in ["_minigame_box", "_newspaper_box", "_quiz_box", "_phrase_box"]:
		var b = D.get(key)
		if b != null and is_instance_valid(b):
			if b.has_method("close"):
				b.close()
			if "visible" in b:
				b.visible = false
	D.hide()
	if A.BookUI.visible:
		A.BookUI.close()
	paused = false
	await _wait(0.4)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for n in ["GameState", "DialogueUI", "BookUI", "WordBank", "QuestManager", "DayNightManager", "Economy", "CharacterRegistry", "ChapterCard"]:
		A[n] = root.get_node(n)
	var GS = A.GameState
	GS.dev_mode = false

	# 1. Main menu
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await _wait(2.0)
	# The paper never names a build: hide the version label in the corner.
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	for l in current_scene.find_children("*", "Label", true, false):
		if l.text == ver:
			l.visible = false
	await _shot("01_main_menu")

	# Game state: Chapters 1-3 done, Chapter 4 under way, words of Chapters 1-4 seen.
	GS.reset_game_state()
	GS.player_name = "Tester"
	for f in ["chapter_card_chapter1_seen", "chapter_card_chapter2_seen", "chapter_card_chapter3_seen", "chapter_card_chapter4_seen",
			"tutorial_ch1_basics_done", "tutorial_ch1_quest_hud_done", "tutorial_ch1_quests_done", "tutorial_ch1_dictionary_done",
			"tutorial_ch1_morning_done", "tutorial_npc_menu_done", "tutorial_money_done", "tutorial_ch2_map_done", "chapter1_complete", "chapter2_tour_done",
			"chapter2_complete", "chapter3_complete", "got_kalibo_map", "map_open_market", "map_open_habuean", "went_fishing",
			"note_story_so_far_seen", "chapter4_started", "chapter4_complete", "note_part_one_end_seen", "seen_chapter2_scene0", "seen_chapter3_scene0", "seen_chapter4_scene0"]:
		GS.set_flag(f)
	# Every tutorial counts as seen, so no tip (e.g. "UI Scale makes...") covers a shot.
	var tuts: Variant = _json("res://data/tutorials/tutorials.json")
	if tuts is Dictionary:
		for id: String in tuts:
			GS.set_flag("tutorial_%s_done" % id)
	# Skip the "Discovered" place banners (v1.1.0): they'd cover the world shots.
	var areas: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_data/area_banners.json"))
	if areas is Dictionary:
		for path: String in areas:
			if areas[path] is Dictionary:
				GS.set_flag("area_banner_%s_seen" % str(areas[path].get("key", path.get_file().get_basename())))
	var n := 0
	for id in A.WordBank.words.keys():
		var w: Dictionary = A.WordBank.words[id]
		if str(w.get("area", "")) in ["chapter1", "chapter2", "chapter3", "chapter4", "all"]:
			GS.expose_word(id)
			GS.adjust_mastery(id, n % 7)
			n += 1
	A.DayNightManager.set_hour(9.5)
	GS.current_level_path = "res://scenes/world/chapter2/pastrana_outdoors.tscn"
	change_scene_to_file("res://scenes/Game.tscn")
	await _wait(7.0)
	await _cleanup()
	var player: Node2D = get_first_node_in_group("player")
	if player != null:
		player.global_position = PASTRANA_SHOT_POS
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam != null:
			cam.offset = PASTRANA_CAM_OFFSET
			cam.reset_smoothing()
		await _wait(1.5)
	await _shot("02_world_pastrana")
	if player != null and player.get_node_or_null("Camera2D") != null:
		player.get_node("Camera2D").offset = Vector2.ZERO
	if only_pastrana:
		quit(0)
		return

	var game = current_scene
	for lv in [["03_world_cathedral", "res://scenes/world/chapter2/cathedral_indoors.tscn"],
			["04_world_market", "res://scenes/world/market/market_indoors.tscn"],
			["05_world_gallery", "res://scenes/world/haboean/haboean_gallery.tscn"],
			["06_world_bakhawan", "res://scenes/world/bakhawan/bakhawan_outdoors.tscn"]]:
		if not ResourceLoader.exists(lv[1]):
			_p("missing level " + lv[1])
			continue
		game.load_level(lv[1])
		await _wait(7.0)
		await _cleanup()
		await _shot(lv[0])
	game.load_level("res://scenes/world/chapter2/pastrana_outdoors.tscn")
	await _wait(3.0)
	await _cleanup()

	# Dialogue line with a tapped word
	var dl := _find_line(2, func(v): return v.get("speaker", "") == "Rose" and str(v.get("text", "")).begins_with("\\Raya do Pastrana"))
	if dl.is_empty():
		dl = {"speaker": "Rose", "text": "\\Raya do Pastrana Park."}
	A.DialogueUI.show_line("Rose", dl.text, null, A.CharacterRegistry.get_portrait("Rose"))
	await _wait(2.5)
	await _shot("07_dialogue")
	var box = A.DialogueUI._dialogue_box
	var lbl = box.text_label
	box._tap_position = Vector2(350, 330)
	box._toggle_word("4:tawo")
	await _shot("08_dialogue_word_tapped")
	await _cleanup()

	# Separated menus (the shipped default): pause menu + one panel per feature
	for tab in ["settings", "dictionary", "bucket_list", "achievements", "map", "calendar"]:
		A.BookUI.open(tab)
		await _wait(1.0)
		await _shot("09_menu_" + ("pause" if tab == "settings" else tab))
		await _cleanup()
	A.BookUI.open("settings")
	await _wait(0.6)
	A.BookUI._get_menus()._open_from_pause("settings")
	await _wait(1.0)
	await _shot("09_menu_settings")
	await _cleanup()

	# Review quiz
	A.DialogueUI.show_review_quiz()
	await _wait(1.5)
	await _shot("10_quiz")
	await _cleanup()

	# Phrase builder (Chapter 1)
	var pb := _find_line(1, func(v): return v.get("type", "") == "phrase_builder")
	if not pb.is_empty():
		# Fill [DayPart] / [good day] the way Comp_Dialogue does before showing it.
		# load() at run time: naming TextUtil here compiles it before the
		# autoloads exist and breaks it for the whole run.
		var text_util: GDScript = load("res://scripts/util/text_util.gd")
		A.DialogueUI.show_phrase_builder(text_util.resolve_builder_line(pb), Node.new())
		await _wait(1.5)
		await _shot("11_phrase_builder")
		await _cleanup()

	var pool: Array = A.WordBank.top_up_pool([], GS.word_exposures.size(), true)
	var mgs := [
		["12_memory_match", {"minigame_type": "memory_match", "word_pool": pool, "pair_count": 6}],
		["13_hangman", {"minigame_type": "hangman", "word_pool": A.WordBank.get_known_puzzle_words(4, 8)}],
		["14_fishing", {"minigame_type": "fishing", "word_pool": pool}],
	]
	var hh := _find_line(3, func(v): return v.get("minigame_type", "") == "habi_habi")
	if not hh.is_empty():
		mgs.append(["15_habi_habi", hh])
	for m in mgs:
		A.DialogueUI.show_standalone_minigame(m[1], func(_p2): pass)
		await _wait(2.5)
		await _shot(m[0])
		await _cleanup()

	# Newspaper: crossword and word search alternate by day
	for i in 2:
		A.DialogueUI.show_newspaper()
		await _wait(1.5)
		await _shot("16_newspaper_%d" % i)
		A.DialogueUI._newspaper_box._on_solve_pressed()
		await _wait(2.0)
		await _shot("16_puzzle_%d" % i)
		await _cleanup()
		GS.date_unix += 86400

	# Market payment
	A.Economy.pay(7, "shop_price")  # a market vendor's price, not a ride fare
	await _wait(2.0)
	await _shot("17_market_pay")

	var f := FileAccess.open(out.path_join("capture.log"), FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	f.close()
	quit(0)
