extends SceneTree
# Captures the extra screenshots the user manual needs (screens the paper's
# capture.gd doesn't take, plus a fresh pause menu).
#   godot --path <project> --script capture_manual.gd -- --save-dir=user://playtest/manual/ --out=<dir>
# Windowed only. Saves go to --save-dir, never the player's slots.

var out := ""
var A := {}
var started := false
var hide_tutorials := true

func _initialize() -> void:
	auto_accept_quit = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)

func _process(_d: float) -> bool:
	if not started:
		started = true
		_run()
	var tm = root.get_node_or_null("TutorialManager")
	if hide_tutorials and tm and "visible" in tm:
		tm.visible = false
	var sq = root.get_node_or_null("Game/UILayer/HUD/QuestColumn/SubQuests")
	if sq:
		sq.modulate.a = 0.0
	return false

func _p(s: String) -> void:
	print("[manual] " + s)

func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout

func _shot(name: String) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	_p("shot " + name)

func _is_ic(c: Node) -> bool:
	var sc = c.get_script()
	return sc != null and str(sc.resource_path).ends_with("Comp_Interactable.gd")

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

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

func _hide_version(scene: Node) -> void:
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	for l in scene.find_children("*", "Label", true, false):
		if l.text == ver:
			l.visible = false

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for n in ["GameState", "DialogueUI", "BookUI", "WordBank", "DayNightManager", "CharacterRegistry"]:
		A[n] = root.get_node(n)
	var GS = A.GameState
	GS.dev_mode = false

	# --- Main menu screens -----------------------------------------------------
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await _wait(2.0)
	_hide_version(current_scene)
	await _shot("m01_main_menu")
	current_scene._open_slots("new")
	await _wait(1.0)
	await _shot("m02_save_slots")
	current_scene._close_slots()
	await _wait(0.5)
	var help: GDScript = load("res://scripts/ui/instructions_panel.gd")
	help.open(self)
	await _wait(1.2)
	await _shot("m03_help")
	for c in root.get_children():
		if c.get_script() == help:
			c.queue_free()
	await _wait(0.5)

	# --- Game state: Chapters 1-4 done, words of Chapters 1-4 seen -------------
	GS.reset_game_state()
	GS.player_name = "Tester"
	for f in ["chapter_card_chapter1_seen", "chapter_card_chapter2_seen", "chapter_card_chapter3_seen", "chapter_card_chapter4_seen",
			"chapter1_complete", "chapter2_tour_done", "chapter2_complete", "chapter3_complete", "got_kalibo_map", "map_open_market",
			"map_open_habuean", "went_fishing", "quest_007_done", "note_story_so_far_seen", "chapter4_started", "chapter4_complete",
			"note_part_one_end_seen", "seen_chapter2_scene0", "seen_chapter3_scene0", "seen_chapter4_scene0"]:
		GS.set_flag(f)
	var tuts: Variant = _json("res://data/tutorials/tutorials.json")
	if tuts is Dictionary:
		for id: String in tuts:
			GS.set_flag("tutorial_%s_done" % id)
	var areas: Variant = _json("res://data/map_data/area_banners.json")
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
	var game = current_scene
	var player: Node2D = get_first_node_in_group("player")

	# --- Game screen with the action button: stand next to a person -----------
	# A "Look" plaque near the Pastrana obelisk: stand just south of it, facing it.
	var hud_btn = root.get_node_or_null("Game/UILayer/HUD/InteractButton")
	var target: Node2D = null
	var best := INF
	for c in game.find_children("*", "", true, false):
		if _is_ic(c) and c.is_visible_in_tree() and str(c.get("interact_label")) == "Look":
			var d: float = c.call("box_center").distance_to(Vector2(632, 864))
			if d < best:
				best = d
				target = c
	if target == null:
		for c in game.find_children("*", "", true, false):
			if _is_ic(c) and c.is_visible_in_tree():
				target = c
				break
	if target != null:
		_p("interactable %s (%s)" % [target.get_parent().name, target.get("interact_label")])
		player.global_position = target.call("box_center") + Vector2(-8, 26)
		if player.get("facing_vec") != null:
			player.set("facing_vec", Vector2.UP)
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam != null:
			cam.offset = Vector2(0, -40)
			cam.reset_smoothing()
		await _wait(2.0)
	_p("interact visible: %s" % [hud_btn.visible if hud_btn else "none"])
	await _shot("m04_game_screen")
	if player.get_node_or_null("Camera2D") != null:
		player.get_node("Camera2D").offset = Vector2.ZERO

	# --- Talk menu --------------------------------------------------------------
	A.DialogueUI.show_npc_interaction_menu("Rose", func(_c): pass)
	await _wait(1.2)
	await _shot("m05_npc_menu")
	await _cleanup()

	# --- A few lines so the conversation log has something in it ---------------
	for line in [["Rose", "\\Maayong \\agahon! Ano ro imong gustong himuon?"], ["Rose", "\\Raya do Pastrana Park."]]:
		A.DialogueUI.show_line(line[0], line[1], null, A.CharacterRegistry.get_portrait(line[0]))
		await _wait(1.5)
	await _cleanup()

	# --- Pause menu and its pages ---------------------------------------------
	A.BookUI.open("settings")
	await _wait(1.0)
	await _shot("m06_pause")
	var menus = A.BookUI._get_menus()
	for id in ["log", "achievements", "settings"]:
		menus._open_from_pause(id)
		await _wait(1.0)
		await _shot("m07_" + id)
		menus.back()
		await _wait(0.6)
	await _cleanup()

	# --- Map with the travel popup ---------------------------------------------
	A.BookUI.open("map")
	await _wait(1.2)
	var map_page = null
	for c in root.find_children("*", "", true, false):
		if c.has_method("_on_marker_pressed"):
			map_page = c
			break
	if map_page != null:
		map_page._on_marker_pressed("market")
		await _wait(1.0)
		await _shot("m08_map_travel")
		map_page._popup._on_back_pressed()
		await _wait(0.5)
	await _cleanup()

	# --- Directions game in Pastrana -------------------------------------------
	var plaza: GDScript = load("res://scripts/util/plaza_game.gd")
	var level: Node = game.get("current_level") if game.get("current_level") != null else player.get_parent()
	var options: Array = plaza.places(level, player.global_position)
	A.DialogueUI.show_standalone_minigame({"minigame_type": "plaza_directions", "level": level,
			"start": player.global_position, "rounds": options.slice(0, 3)}, func(_p2): pass)
	await _wait(2.5)
	await _shot("m09_directions")
	await _cleanup()

	# --- Stall help at the market ----------------------------------------------
	game.load_level("res://scenes/world/market/market_indoors.tscn")
	await _wait(7.0)
	await _cleanup()
	var stall: GDScript = load("res://scripts/util/stall_helper.gd")
	A.DialogueUI.show_standalone_minigame(stall.STALL_LINE.duplicate(true), func(_p2): pass)
	await _wait(2.5)
	await _shot("m10_stall")
	await _cleanup()

	quit(0)
