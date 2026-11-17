extends SceneTree
# Cap101 static checker: loads every scene and data file and reports broken links
# (warps to missing scenes or spawns, cutscene markers, dialogue indices, word ids,
# flags nothing sets, ...). Every finding gets an image in <out>/shots/:
#   - level problems: the level rendered around the spot, with a red box on it
#   - data problems: a card showing the file, the entry and the offending JSON
#
#   godot --path <project> --script validate.gd -- --out=<dir>
# Run windowed: images need a real renderer. Writes <out>/static_findings.json.

const MAX_SHOTS := 60

var MarkerUtil
var out := ""
var levels := {}
var all_text := ""
var findings: Array = []
var _started := false
var _shots := 0

func _initialize() -> void:
	auto_accept_quit = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)

func _process(_d: float) -> bool:
	if _started:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	if out == "":
		push_error("validate: --out=DIR is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out.path_join("shots"))
	MarkerUtil = load("res://scripts/util/marker_util.gd")
	for d in ["res://scripts", "res://data", "res://scenes"]:
		_collect_text(d)
	var scenes := []
	_list("res://scenes", ".tscn", scenes)
	for p in scenes:
		var ps = load(p)
		if ps == null:
			_issue("scene_load", "scene fails to load: %s" % p, {"file": p})
			continue
		var inst = ps.instantiate()
		if p.begins_with("res://scenes/world/") and not p.contains("_templates"):
			levels[p] = inst
		else:
			inst.free()
	_check_levels()
	_check_cutscenes()
	_check_dialogue()
	_check_npc_scenes(scenes)
	_check_economy()
	# Images, one finding at a time.
	for f in findings:
		if _shots >= MAX_SHOTS:
			break
		f["screenshot"] = await _render(f)
	var file := FileAccess.open(out.path_join("static_findings.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"findings": findings}, "\t"))
	file.close()
	print("VALIDATION DONE: %d findings" % findings.size())
	for l in levels.values():
		l.free()
	quit(0)

## extra: level (res path) + pos (Vector2) for level problems, or file + snippet for data.
func _issue(cat: String, message: String, extra: Dictionary = {}) -> void:
	var f := {"id": findings.size() + 1, "category": cat, "message": message, "screenshot": ""}
	f.merge(extra)
	if f.has("pos"):
		f["pos"] = [f.pos.x, f.pos.y]
	findings.append(f)
	print("ISSUE|%s|%s" % [cat, message])

# --- images -------------------------------------------------------------------
func _render(f: Dictionary) -> String:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.14)
	bg.size = Vector2(640, 360)
	if f.has("level") and levels.has(f.level):
		var canvas := Node2D.new()
		vp.add_child(canvas)
		var lvl: Node2D = load(f.level).instantiate()
		# The level's own story script would start cutscenes with no Game around it.
		lvl.set_script(null)
		canvas.add_child(lvl)
		var cam := Camera2D.new()
		var at := Vector2(f.pos[0], f.pos[1]) if f.has("pos") else Vector2.ZERO
		cam.position = at
		cam.zoom = Vector2(1.25, 1.25)
		canvas.add_child(cam)
		cam.make_current()
		if f.has("pos"):
			var box := ReferenceRect.new()
			box.border_color = Color.RED
			box.border_width = 2.0
			box.editor_only = false
			box.position = at - Vector2(16, 16)
			box.size = Vector2(32, 32)
			box.z_index = 100
			canvas.add_child(box)
		var cap := CanvasLayer.new()
		vp.add_child(cap)
		cap.add_child(_caption("#%d %s\n%s" % [f.id, f.category, f.message]))
	else:
		vp.add_child(bg)
		var lbl := _caption("#%d %s\n%s\n\n%s" % [f.id, f.category, f.message, str(f.get("snippet", "")).left(900)])
		lbl.size = Vector2(620, 340)
		vp.add_child(lbl)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var rel := "shots/static_%03d_%s.png" % [f.id, f.category]
	vp.get_texture().get_image().save_png(out.path_join(rel))
	vp.queue_free()
	_shots += 1
	return rel

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(10, 8)
	l.size = Vector2(620, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

# --- helpers ------------------------------------------------------------------
func _list(dir: String, ext: String, outl: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(ext):
			outl.append(dir + "/" + f)
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "archived":
			continue
		_list(dir + "/" + sub, ext, outl)

func _collect_text(dir: String) -> void:
	var files := []
	for ext in [".gd", ".json", ".tscn"]:
		_list(dir, ext, files)
	for f in files:
		all_text += FileAccess.get_file_as_string(f) + "\n"

func _flag_is_set_somewhere(flag: String) -> bool:
	for pt in ["\"flag\": \"%s\"" % flag, "\"flag\":\"%s\"" % flag, "set_flag(\"%s\"" % flag, "\"set_flag\": \"%s\"" % flag,
			"\"set_flag_on_enter\": \"%s\"" % flag, "\"completion_flag\": \"%s\"" % flag,
			"sleep_flag = \"%s\"" % flag]:  # sleep_bed.gd export in a .tscn
		if all_text.contains(pt):
			return true
	var re := RegEx.new()
	re.compile("(?m)^const\\s+(\\w+)[^=]*=\\s*\"%s\"" % flag)
	for m in re.search_all(all_text):
		if all_text.contains("set_flag(%s" % m.get_string(1)):
			return true
	return false

# --- checks -------------------------------------------------------------------
func _check_levels() -> void:
	var MM = root.get_node("MapManager")
	for p in levels:
		var lvl: Node = levels[p]
		if MarkerUtil.find(lvl, "DefaultSpawn") == null:
			_issue("level_no_default_spawn", "%s has no DefaultSpawn marker" % p.get_file(), {"level": p})
		if MM.area_for_scene(p) == "":
			_issue("level_no_area", "%s is missing from data/map_data/level_areas.json" % p.get_file(), {"level": p})
		for w in lvl.find_children("*", "Area2D", true, false):
			var ts = w.get("target_scene")
			if ts == null:
				continue
			var at: Vector2 = w.global_position
			var label := "%s :: %s" % [p.get_file(), lvl.get_path_to(w)]
			if str(ts) == "":
				# A closed_message marks a door that's closed on purpose (comp_warp.gd).
				if str(w.get("closed_message")).is_empty():
					_issue("warp_no_target", "%s has no target_scene" % label, {"level": p, "pos": at})
				continue
			if not ResourceLoader.exists(ts):
				_issue("warp_missing_scene", "%s -> missing %s" % [label, ts], {"level": p, "pos": at})
				continue
			var sid := str(w.get("target_spawn_id"))
			if levels.has(ts) and sid != "" and MarkerUtil.find(levels[ts], sid) == null:
				_issue("warp_missing_spawn", "%s -> %s has no marker '%s'" % [label, ts.get_file(), sid], {"level": p, "pos": at})
			var rf := str(w.get("required_flag"))
			if rf != "" and not _flag_is_set_somewhere(rf):
				_issue("warp_flag_never_set", "%s needs flag '%s', which nothing sets" % [label, rf], {"level": p, "pos": at})

func _check_cutscenes() -> void:
	var files := []
	_list("res://data/cutscenes", ".json", files)
	var known: Array = root.get_node("CutsceneManager")._actions.keys() + ["parallel", "sequence"]
	var level_src := {}
	for p in levels:
		var s = levels[p].get_script()
		level_src[p] = s.source_code if s else ""
	for f in files:
		var id: String = f.get_file().get_basename()
		var data = JSON.parse_string(FileAccess.get_file_as_string(f))
		if not data is Array:
			_issue("cutscene_bad_json", "%s is not a JSON array" % f, {"file": f})
			continue
		if not all_text.contains("\"%s\"" % id):
			_issue("cutscene_unreferenced", "cutscene %s is never played from anywhere" % id, {"file": f})
		var cands := []
		for p in level_src:
			if level_src[p].contains("\"%s\"" % id):
				cands.append(p)
		_walk(id, f, data, cands, known)

func _walk(id: String, file: String, steps: Array, cands: Array, known: Array) -> void:
	for step in steps:
		if not step is Dictionary:
			continue
		var t: String = step.get("type", "")
		var snip := JSON.stringify(step)
		if not t in known:
			_issue("cutscene_unknown_type", "%s uses unknown step type '%s'" % [id, t], {"file": file, "snippet": snip})
		match t:
			"parallel", "sequence":
				_walk(id, file, step.get("actions", []), cands, known)
			"dialogue":
				if root.get_node("ChapterLoader").get_scene_lines(step.get("chapter", ""), step.get("scene", "")).is_empty():
					_issue("cutscene_missing_dialogue", "%s plays missing dialogue %s/%s" % [id, step.get("chapter", ""), step.get("scene", "")], {"file": file, "snippet": snip})
			"load_scene":
				var sp: String = step.get("scene_path", "")
				if not ResourceLoader.exists(sp):
					_issue("cutscene_missing_scene", "%s loads missing scene %s" % [id, sp], {"file": file, "snippet": snip})
				else:
					cands = [sp]
			"spawn_npc":
				if not ResourceLoader.exists(step.get("scene", "")):
					_issue("cutscene_missing_npc_scene", "%s spawns missing %s" % [id, step.get("scene", "")], {"file": file, "snippet": snip})
				_marker(id, file, snip, step.get("at_marker", null), cands)
			"move_npc":
				_marker(id, file, snip, step.get("from", null), cands)
				_marker(id, file, snip, step.get("to", null), cands)
			"conga":
				_marker(id, file, snip, step.get("path_to", null), cands)
				for wp in step.get("waypoints", []):
					_marker(id, file, snip, wp, cands)

func _marker(id: String, file: String, snip: String, ref, cands: Array) -> void:
	if not ref is String or ref == "":
		return
	var pool: Array = cands if not cands.is_empty() else levels.keys()
	for p in pool:
		if levels.has(p) and MarkerUtil.find(levels[p], ref) != null:
			return
	var extra := {"file": file, "snippet": snip}
	if cands.size() == 1:
		extra["level"] = cands[0]
	_issue("cutscene_missing_marker", "%s: marker '%s' not found in %s" % [id, ref, "any level" if cands.is_empty() else ", ".join(cands.map(func(x): return x.get_file()))], extra)

func _check_dialogue() -> void:
	var WB = root.get_node("WordBank")
	_build_form_index(WB)
	var playable := _playable_chapters()
	for ch in ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5", "chapter6"]:
		var path := "res://data/dialogue/%s.json" % ch
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			_issue("dialogue_bad_json", "%s does not parse" % path, {"file": path})
			continue
		_check_remarks(ch, path, data.get("remarks", {}), playable.has(ch))
		for key in data:
			var lines = data[key]
			if not lines is Array:
				continue
			var n: int = lines.size()
			var reachable := {}
			for i in n:
				var line = lines[i]
				if not line is Dictionary:
					continue
				var tag := "%s/%s[%d]" % [ch, key, i]
				var extra := {"file": path, "snippet": JSON.stringify(line, "  ")}
				var targets := []
				for k in ["next", "success", "failure", "check_flag_next", "next_on_pass"]:
					if line.has(k) and line[k] != null:
						targets.append(line[k])
				# phrase builder / minigame lines keep word lists in "choices"
				for c in line.get("choices", []):
					if c is Dictionary and c.has("next") and c["next"] != null and int(c["next"]) != -1:
						targets.append(c["next"])
				for b in line.get("patience_branch", []):
					targets.append(b.get("next"))
				if line.get("type", "") == "start_router":
					var routes: Dictionary = line.get("start_index_if_flag", {})
					for fk in routes:
						targets.append(routes[fk])
						if fk != "default" and not _flag_is_set_somewhere(fk):
							_issue("dialogue_flag_never_set", "%s routes on flag '%s', which nothing sets" % [tag, fk], extra)
				for t in targets:
					if t == null:
						continue
					if int(t) < 0 or int(t) >= n:
						_issue("dialogue_bad_index", "%s jumps to %s but the scene has %d lines" % [tag, t, n], extra)
					else:
						reachable[int(t)] = true
				var bubble = line.get("bubble", null)
				if bubble != null:
					for icon in (bubble if bubble is Array else [bubble]):
						if not root.get_node("PictureBubbles").has_icon(str(icon)):
							_issue("dialogue_unknown_bubble", "%s shows bubble icon '%s', which data/bubble_icons.json doesn't have" % [tag, icon], extra)
				var cf := str(line.get("check_flag", ""))
				if cf != "" and not _flag_is_set_somewhere(cf):
					_issue("dialogue_flag_never_set", "%s checks flag '%s', which nothing sets" % [tag, cf], extra)
				for wid in line.get("word_ids", []):
					var w: String = str(wid).strip_edges()
					if w != "" and not w.begins_with("[") and WB.get_word(w).is_empty():
						_issue("dialogue_unknown_word", "%s tags unknown word id '%s'" % [tag, w], extra)
				if playable.has(ch) and line.get("type", "dialogue") == "dialogue":
					_check_word_tags(tag, line, extra, WB)
				# A choice line with no text keeps the previous line up as its prompt
				# (Comp_Dialogue._show_line), so it's only a problem as the first
				# line on screen: nothing with text leads into it.
				if line.get("type", "dialogue") == "dialogue" and line.has("choices") and str(line.get("text", "")).strip_edges() == "" \
						and not _has_text_before(lines, i):
					_issue("dialogue_empty_text", "%s is a choice line with no text and no line before it to keep on screen (box shows '…')" % tag, extra)
			if not key.begins_with("idle"):
				for i in range(1, n):
					var prev = lines[i - 1]
					var falls_through: bool = prev is Dictionary and not prev.has("next") and not prev.has("choices") \
						and prev.get("type", "") != "start_router"
					if not reachable.has(i) and not falls_through:
						_issue("dialogue_unreachable", "%s/%s[%d] can never be reached" % [ch, key, i], {"file": path, "snippet": JSON.stringify(lines[i], "  ")})

## Chapters marked available in data/chapters.json: the only ones whose Akeanon
## tagging is checked (later chapters are drafts).
func _playable_chapters() -> Array:
	var out_ids := []
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	if data is Array:
		for c in data:
			if c is Dictionary and c.get("available", false):
				out_ids.append(str(c.get("id", "")))
	return out_ids

## plain form (WordBank.plain_form) -> every word id with that spelling, its
## "/" variants, or one of a phrase's words.
var _form_ids := {}
func _build_form_index(WB) -> void:
	for id in WB.words:
		var forms := []
		for part in str(WB.words[id]["akeanon"]).to_lower().split("/", false):
			part = part.strip_edges()
			forms.append(part)
			for tok in part.split(" ", false):
				forms.append(tok)
		for f in forms:
			var k: String = WB.plain_form(f)
			if not _form_ids.has(k):
				_form_ids[k] = []
			if not _form_ids[k].has(id):
				_form_ids[k].append(id)

## The roadmap's tagging rule (STORY_ROADMAP.md §7.1): every \marked word is in
## the bank and tagged in word_ids, and every tagged word is said in the line.
const MARKED_WORD := "\\\\([^\\s.,!?;:\"()—–…“”‘’]+)"
func _check_word_tags(tag: String, line: Dictionary, extra: Dictionary, WB) -> void:
	var text := str(line.get("text", ""))
	var ids: Array = line.get("word_ids", []).map(func(w): return str(w).strip_edges()) \
			.filter(func(w): return w != "" and not w.begins_with("["))
	var re := RegEx.create_from_string(MARKED_WORD)
	for m in re.search_all(text):
		var form: String = m.get_string(1).trim_suffix("-")
		if form.begins_with("[") or form.is_empty():
			continue
		var cands: Array = _form_ids.get(WB.plain_form(form), [])
		if cands.is_empty():
			_issue("dialogue_marked_unknown", "%s marks '%s', which isn't in the word bank" % [tag, form], extra)
		elif not cands.any(func(c): return ids.has(c)):
			_issue("dialogue_marked_untagged", "%s marks '%s' but word_ids doesn't tag it" % [tag, form], extra)
	var said: String = WB.plain_form(text.replace("\\", ""))
	for wid in ids:
		var w: Dictionary = WB.get_word(wid)
		if w.is_empty():
			continue  # already a dialogue_unknown_word
		var found := false
		for part in str(w["akeanon"]).to_lower().split("/", false):
			if said.contains(WB.plain_form(part.strip_edges())):
				found = true
		if not found:
			_issue("dialogue_id_not_in_line", "%s tags %s '%s', which the line doesn't say" % [tag, wid, w["akeanon"]], extra)

## True if a dialogue line with text leads into line `i` (its "next", or by
## falling through as the line just before it).
func _has_text_before(lines: Array, i: int) -> bool:
	for j in lines.size():
		var l = lines[j]
		if not l is Dictionary or str(l.get("text", "")).strip_edges() == "" or l.has("choices"):
			continue
		var nxt = l.get("next", j + 1 if not l.has("next") else null)
		if nxt != null and int(nxt) == i:
			return true
	return false

func _check_npc_scenes(scenes: Array) -> void:
	var CL = root.get_node("ChapterLoader")
	for p in scenes:
		if not p.contains("/entities/npc_"):
			continue
		var inst = load(p).instantiate()
		var key = inst.get("dialogue_scene_key")
		var ch = inst.get("dialogue_chapter")
		if key != null and str(key) != "" and CL.get_scene_lines(str(ch), str(key)).is_empty():
			_issue("npc_missing_dialogue", "%s defaults to dialogue %s/%s, which doesn't exist" % [p.get_file(), ch, key], {"file": p})
		inst.free()

## Story remarks (IdleTalk): each needs a speaker and lines, its flags must be
## set somewhere, and its lines' word ids must exist.
func _check_remarks(ch: String, path: String, remarks, check_tags: bool = false) -> void:
	if not remarks is Dictionary:
		_issue("remark_bad_shape", "%s: \"remarks\" must be an object keyed by remark id" % ch, {"file": path})
		return
	var WB = root.get_node("WordBank")
	for rid in remarks:
		var r = remarks[rid]
		var tag := "%s/remarks/%s" % [ch, rid]
		var extra := {"file": path, "snippet": JSON.stringify(r, "  ")}
		if not r is Dictionary or str(r.get("speaker", "")).is_empty() or not r.get("lines", []) is Array or r.get("lines", []).is_empty():
			_issue("remark_bad_shape", "%s needs a speaker and at least one line" % tag, extra)
			continue
		for f in r.get("requires", []) + r.get("unless", []):
			if not _flag_is_set_somewhere(str(f)):
				_issue("remark_flag_never_set", "%s depends on flag '%s', which nothing sets" % [tag, f], extra)
		for line in r["lines"]:
			for wid in line.get("word_ids", []):
				if WB.get_word(str(wid)).is_empty():
					_issue("dialogue_unknown_word", "%s tags unknown word id '%s'" % [tag, wid], extra)
			if check_tags:
				_check_word_tags(tag, line, extra, WB)

## Economy data (docs/ECONOMY_PLAN.md): every map region with a fare has a scene
## that exists and an unlock flag something sets; every item a quest or shop
## names exists in data/items.json, keepsakes are never sellable, and every
## line key a side quest uses exists in data/economy_lines.json.
func _check_economy() -> void:
	var regions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_data/regions.json"))
	var items_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var lines: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy_lines.json"))
	var quests: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/quest_data.json"))
	if not (regions is Dictionary and items_data is Dictionary and lines is Dictionary and quests is Dictionary):
		_issue("economy_data", "regions.json, items.json, economy_lines.json or quest_data.json does not parse")
		return
	var items: Dictionary = items_data.get("items", {})
	for rid in regions:
		var r: Dictionary = regions[rid]
		if int(r.get("fare", 0)) <= 0:
			continue
		var scene: String = str(r.get("scene_path", ""))
		if scene.is_empty() or not ResourceLoader.exists(scene):
			_issue("economy_fare_region", "region '%s' has a fare but no scene (%s)" % [rid, scene], {"file": "res://data/map_data/regions.json"})
		var req: String = str(r.get("requires_flag", ""))
		if not req.is_empty() and not _flag_is_set_somewhere(req):
			_issue("economy_fare_region", "region '%s' requires flag '%s', which nothing sets" % [rid, req], {"file": "res://data/map_data/regions.json"})
	for iid in items:
		var it: Dictionary = items[iid]
		if it.get("kind", "") == "keepsake" and bool(it.get("sellable", false)):
			_issue("economy_item", "keepsake '%s' is marked sellable" % iid, {"file": "res://data/items.json"})
		var wid: String = str(it.get("akeanon_word_id", ""))
		if not wid.is_empty() and not all_text.contains("\"id\": \"%s\"" % wid):
			_issue("economy_item", "item '%s' uses word %s, not in the word bank" % [iid, wid], {"file": "res://data/items.json"})
	var shops: Dictionary = items_data.get("shops", {})
	for sid in shops:
		for iid in shops[sid].get("stock", []):
			if not items.has(iid):
				_issue("economy_item", "shop '%s' sells unknown item '%s'" % [sid, iid], {"file": "res://data/items.json"})
	for q: Dictionary in quests.get("quests", []):
		if q.get("category", "") != "side":
			continue
		for iid in q.get("needs_items", {}):
			if not items.has(iid):
				_issue("economy_quest", "side quest %s needs unknown item '%s'" % [q.get("id", "?"), iid], {"file": "res://data/quest_data.json"})
		var keys: Array = []
		for k in q.get("lines", {}):
			var v = q["lines"][k]
			keys.append_array(v if v is Array else [v])
		for key in keys:
			if not lines.has(str(key)):
				_issue("economy_quest", "side quest %s uses line '%s', not in economy_lines.json" % [q.get("id", "?"), key], {"file": "res://data/quest_data.json"})
