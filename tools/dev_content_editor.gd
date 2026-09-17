# dev_content_editor.gd — standalone content-authoring tool, NOT part of the
# shipped game. Open scenes/devtools/dev_content_editor.tscn in the Godot
# editor and hit "Run Current Scene" (F6) to use it. Reads/writes res://
# directly via FileAccess -- only works run this way (uncompiled project),
# same constraint as every other res:// write in this codebase (TDD §9 item
# 1, Android PCK). Never add this scene to an exported build.
#
# Covers: data/dialogue/chapterN.json (story scenes + idle pools) and
# data/challenges/chapterN.json (Ch2-style challenge entries). Built for a
# non-coder teammate -- dropdowns/pickers instead of raw index typing,
# nothing saves without passing Validate first, deletions auto-remap "next"
# references so the self-loop / out-of-bounds bugs we hand-fixed earlier
# can't reoccur through this tool.
extends Control

const CHAPTER_IDS := ["chapter1", "chapter2", "chapter3", "chapter4", "chapter5", "chapter6"]
const DIALOGUE_PATH_FMT := "res://data/dialogue/%s.json"
const CHALLENGE_PATH_FMT := "res://data/challenges/%s.json"
const WORD_BANK_PATH := "res://data/word_bank.json"
const REGIONS_PATH := "res://data/map_data/regions.json"
const TIER_KEYS := ["low", "med", "high"]

# --- Loaded data (mutated in place by the UI, written out on Save) ---
var current_chapter: String = ""
var dialogue_data: Dictionary = {}     # full parsed chapterN.json
var challenge_data: Dictionary = {}    # full parsed challenges/chapterN.json, {} if file absent
var word_bank_ids: Array = []          # for word_ids cross-check (warn only, never block)
var region_keys: Array = []            # for unlock_target cross-check (warn only, never block)

var current_scene_key: String = ""
var current_pool_key: String = ""
var current_challenge_id: String = ""

# --- UI refs, built in _ready() ---
var chapter_option: OptionButton
var status_label: Label
var main_tabs: TabContainer

var scene_list: ItemList
var scene_editor_box: VBoxContainer
var pool_list: ItemList
var tier_tab: TabContainer
var tier_boxes: Dictionary = {}        # "low"/"med"/"high"/"overrides" -> VBoxContainer
var challenge_list: ItemList
var challenge_editor_box: VBoxContainer

var validation_log: RichTextLabel

func _ready() -> void:
	_load_word_bank()
	_load_regions()
	_build_ui()
	chapter_option.select(0)
	_on_chapter_selected(0)

# ============================================================
# Cross-reference data (warn-only, never blocks saving)
# ============================================================

func _load_word_bank() -> void:
	word_bank_ids.clear()
	if not FileAccess.file_exists(WORD_BANK_PATH):
		return
	var f := FileAccess.open(WORD_BANK_PATH, FileAccess.READ)
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK:
		for w in j.get_data().get("words", []):
			word_bank_ids.append(w.get("id", ""))
	f.close()

func _load_regions() -> void:
	region_keys.clear()
	if not FileAccess.file_exists(REGIONS_PATH):
		return
	var f := FileAccess.open(REGIONS_PATH, FileAccess.READ)
	var j := JSON.new()
	if j.parse(f.get_as_text()) == OK:
		region_keys = j.get_data().keys()
	f.close()

# ============================================================
# Top-level UI scaffold
# ============================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# --- Top bar ---
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	top_bar.add_child(_label("Chapter:"))
	chapter_option = OptionButton.new()
	for cid in CHAPTER_IDS:
		chapter_option.add_item(cid)
	chapter_option.item_selected.connect(_on_chapter_selected)
	top_bar.add_child(chapter_option)

	var reload_btn := Button.new()
	reload_btn.text = "Reload (discard unsaved edits)"
	reload_btn.pressed.connect(func(): _on_chapter_selected(chapter_option.selected))
	top_bar.add_child(reload_btn)

	var validate_btn := Button.new()
	validate_btn.text = "Validate"
	validate_btn.pressed.connect(_run_validation)
	top_bar.add_child(validate_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	top_bar.add_child(save_btn)

	status_label = _label("")
	top_bar.add_child(status_label)

	# --- Main tabs ---
	main_tabs = TabContainer.new()
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_tabs)

	main_tabs.add_child(_build_dialogue_tab())
	main_tabs.add_child(_build_idle_tab())
	main_tabs.add_child(_build_challenge_tab())
	main_tabs.set_tab_title(0, "Dialogue Scenes")
	main_tabs.set_tab_title(1, "Idle Pools")
	main_tabs.set_tab_title(2, "Challenges")

	# --- Validation log ---
	validation_log = RichTextLabel.new()
	validation_log.bbcode_enabled = true
	validation_log.custom_minimum_size = Vector2(0, 160)
	validation_log.text = "[i]Run Validate before Save. Nothing here yet.[/i]"
	root.add_child(validation_log)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.free()

# ============================================================
# Chapter load
# ============================================================

func _on_chapter_selected(idx: int) -> void:
	current_chapter = CHAPTER_IDS[idx]
	dialogue_data = _load_json(DIALOGUE_PATH_FMT % current_chapter)
	challenge_data = _load_json(CHALLENGE_PATH_FMT % current_chapter)  # {} if file absent, that's fine
	current_scene_key = ""
	current_pool_key = ""
	current_challenge_id = ""
	_refresh_scene_list()
	_refresh_pool_list()
	_refresh_challenge_list()
	validation_log.text = "[i]Loaded %s. Run Validate before Save.[/i]" % current_chapter
	status_label.text = ""

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var j := JSON.new()
	var err := j.parse(f.get_as_text())
	f.close()
	if err != OK:
		status_label.text = "PARSE ERROR in %s: %s" % [path, j.get_error_message()]
		return {}
	return j.get_data()

func _save_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", false))
	f.store_string("\n")
	f.close()
	return true

func _on_save_pressed() -> void:
	var issues := _validate_all()
	if not issues.is_empty():
		_show_validation(issues)
		status_label.text = "NOT SAVED -- fix the issues below first."
		return
	var ok1 := _save_json(DIALOGUE_PATH_FMT % current_chapter, dialogue_data)
	var ok2 := true
	if not challenge_data.is_empty():
		ok2 = _save_json(CHALLENGE_PATH_FMT % current_chapter, challenge_data)
	status_label.text = "Saved %s" % current_chapter if (ok1 and ok2) else "SAVE FAILED -- check file permissions"

# ============================================================
# Shared line-editor row (used by both Dialogue Scenes and Idle Pools)
# is_full: true = dialogue scene line (has next/choices/router-adjacent
# fields), false = idle line (leaf only: speaker/text/translation/word_ids)
# ============================================================

func _build_line_row(line: Dictionary, lines_array: Array, index: int, is_full: bool, on_change: Callable) -> Control:
	var box := PanelContainer.new()
	var vb := VBoxContainer.new()
	box.add_child(vb)

	var header := HBoxContainer.new()
	header.add_child(_label("Line %d" % index))

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.pressed.connect(func():
		_delete_line_with_remap(lines_array, index)
		on_change.call()
	)
	header.add_child(del_btn)
	vb.add_child(header)

	# Router special-case: index 0 with start_index_if_flag is edited as a
	# router panel, not a normal line -- skip normal fields entirely.
	if index == 0 and line.has("start_index_if_flag"):
		vb.add_child(_build_router_editor(line, lines_array))
		return box

	var speaker_row := HBoxContainer.new()
	speaker_row.add_child(_label("Speaker:"))
	var speaker_edit := LineEdit.new()
	speaker_edit.text = line.get("speaker", "")
	speaker_edit.custom_minimum_size = Vector2(160, 0)
	speaker_edit.text_changed.connect(func(t): line["speaker"] = t)
	speaker_row.add_child(speaker_edit)
	vb.add_child(speaker_row)

	var text_row := HBoxContainer.new()
	text_row.add_child(_label("Text:"))
	var text_edit := LineEdit.new()
	text_edit.text = line.get("text", "")
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(func(t): line["text"] = t)
	text_row.add_child(text_edit)
	vb.add_child(text_row)

	var trans_row := HBoxContainer.new()
	trans_row.add_child(_label("Translation (dev/QA only, never shown to player):"))
	var trans_edit := LineEdit.new()
	trans_edit.text = line.get("translation", "")
	trans_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trans_edit.text_changed.connect(func(t):
		if t.is_empty():
			line.erase("translation")
		else:
			line["translation"] = t
	)
	trans_row.add_child(trans_edit)
	vb.add_child(trans_row)

	var word_row := HBoxContainer.new()
	word_row.add_child(_label("word_ids (comma-separated):"))
	var word_edit := LineEdit.new()
	word_edit.text = ",".join(line.get("word_ids", []))
	word_edit.custom_minimum_size = Vector2(200, 0)
	word_edit.text_changed.connect(func(t):
		var ids: Array = []
		for part in t.split(","):
			var trimmed: String = part.strip_edges()
			if not trimmed.is_empty():
				ids.append(trimmed)
		line["word_ids"] = ids
	)
	word_row.add_child(word_edit)
	var word_warn := _label("")
	word_row.add_child(word_warn)
	# Live warn (not block) on unknown word ids.
	word_edit.text_changed.connect(func(_t):
		var unknown: Array = []
		for wid in line.get("word_ids", []):
			if not word_bank_ids.has(wid):
				unknown.append(wid)
		word_warn.text = ("  ⚠ not in word_bank.json: " + ",".join(unknown)) if not unknown.is_empty() else ""
	)
	vb.add_child(word_row)

	if is_full:
		# set_flag_on_enter -- optional, warns if left as empty string
		# (exactly the placeholder-scaffold bug we stripped earlier).
		var flag_row := HBoxContainer.new()
		flag_row.add_child(_label("set_flag_on_enter (optional):"))
		var flag_edit := LineEdit.new()
		flag_edit.text = line.get("set_flag_on_enter", "")
		flag_edit.placeholder_text = "leave blank for none -- do not save as empty string"
		flag_edit.text_changed.connect(func(t):
			if t.is_empty():
				line.erase("set_flag_on_enter")
			else:
				line["set_flag_on_enter"] = t
		)
		flag_row.add_child(flag_edit)
		vb.add_child(flag_row)

		# next -- dropdown of every line in this scene, previewed by text,
		# plus "None (ends dialogue)". Never a bare typed integer.
		var next_row := HBoxContainer.new()
		next_row.add_child(_label("Next:"))
		var next_option := OptionButton.new()
		_populate_next_dropdown(next_option, lines_array, line.get("next"))
		next_option.item_selected.connect(func(sel_idx):
			var meta = next_option.get_item_metadata(sel_idx)
			line["next"] = meta
		)
		next_row.add_child(next_option)
		vb.add_child(next_row)

		# choices -- optional branch. Toggle adds/removes the array.
		var has_choices: bool = line.has("choices") and not line["choices"].is_empty()
		var choices_toggle := CheckButton.new()
		choices_toggle.text = "Has choices (branch)"
		choices_toggle.button_pressed = has_choices
		vb.add_child(choices_toggle)

		var choices_box := VBoxContainer.new()
		vb.add_child(choices_box)
		if has_choices:
			_build_choices_editor(choices_box, line, lines_array)

		choices_toggle.toggled.connect(func(pressed):
			if pressed:
				if not line.has("choices"):
					line["choices"] = []
				line["next"] = null   # choice lines use per-choice next, not line-level next
				if line["choices"].is_empty():
					line["choices"].append({"label": "", "next": null})
				_clear(choices_box)
				_build_choices_editor(choices_box, line, lines_array)
			else:
				line.erase("choices")
				# Restore sequential fallthrough so "next" doesn't dangle at
				# null after removing the branch.
				line["next"] = (index + 1) if (index + 1 < lines_array.size()) else null
				_clear(choices_box)
			on_change.call()
		)

	return box

func _populate_next_dropdown(option: OptionButton, lines_array: Array, current_value) -> void:
	option.clear()
	option.add_item("None (ends dialogue)")
	option.set_item_metadata(0, null)
	var select_idx := 0
	for i in range(lines_array.size()):
		var preview: String = str(lines_array[i].get("text", lines_array[i].get("start_index_if_flag", "")))
		if preview.length() > 40:
			preview = preview.substr(0, 40) + "..."
		option.add_item("%d: %s" % [i, preview])
		option.set_item_metadata(option.item_count - 1, i)
		if current_value == i:
			select_idx = option.item_count - 1
	option.select(select_idx)

func _build_choices_editor(choices_box: Container, line: Dictionary, lines_array: Array) -> void:
	_clear(choices_box)
	var choices: Array = line["choices"]
	for ci in range(choices.size()):
		var choice: Dictionary = choices[ci]
		var row := HBoxContainer.new()
		row.add_child(_label("Choice %d label:" % ci))
		var label_edit := LineEdit.new()
		label_edit.text = choice.get("label", "")
		label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_edit.text_changed.connect(func(t): choice["label"] = t)
		row.add_child(label_edit)

		row.add_child(_label("-> Next:"))
		var next_opt := OptionButton.new()
		_populate_next_dropdown(next_opt, lines_array, choice.get("next"))
		next_opt.item_selected.connect(func(sel_idx): choice["next"] = next_opt.get_item_metadata(sel_idx))
		row.add_child(next_opt)

		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.pressed.connect(func():
			choices.remove_at(ci)
			_build_choices_editor(choices_box, line, lines_array)
		)
		row.add_child(remove_btn)
		choices_box.add_child(row)

	var add_btn := Button.new()
	add_btn.text = "Add Choice"
	add_btn.pressed.connect(func():
		choices.append({"label": "", "next": null})
		_build_choices_editor(choices_box, line, lines_array)
	)
	choices_box.add_child(add_btn)

# ============================================================
# Router editor (scene index 0 with start_index_if_flag)
# ============================================================

func _build_router_editor(router_line: Dictionary, lines_array: Array) -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(_label("[Scene Router] Picks which line this scene starts on, based on flags set earlier."))
	router_line["type"] = "start_router"   # always enforced, never editable off

	var flag_map: Dictionary = router_line.get("start_index_if_flag", {})
	if not flag_map.has("default"):
		flag_map["default"] = 0
	router_line["start_index_if_flag"] = flag_map

	var rows_box := VBoxContainer.new()
	vb.add_child(rows_box)

	var rebuild: Callable
	rebuild = func():
		_clear(rows_box)
		for flag_id in flag_map.keys():
			var row := HBoxContainer.new()
			if flag_id == "default":
				row.add_child(_label("default (required, always checked last):"))
			else:
				var name_edit := LineEdit.new()
				name_edit.text = flag_id
				name_edit.custom_minimum_size = Vector2(180, 0)
				name_edit.text_submitted.connect(func(new_name):
					if new_name != flag_id and not new_name.is_empty() and not flag_map.has(new_name):
						flag_map[new_name] = flag_map[flag_id]
						flag_map.erase(flag_id)
						rebuild.call()
				)
				row.add_child(name_edit)

			var target_opt := OptionButton.new()
			_populate_next_dropdown(target_opt, lines_array, flag_map[flag_id])
			# Router targets can't be "None" -- force a real line if user picks it.
			target_opt.item_selected.connect(func(sel_idx):
				var meta = target_opt.get_item_metadata(sel_idx)
				flag_map[flag_id] = meta if meta != null else 0
			)
			row.add_child(target_opt)

			if flag_id != "default":
				var remove_btn := Button.new()
				remove_btn.text = "Remove"
				remove_btn.pressed.connect(func():
					flag_map.erase(flag_id)
					rebuild.call()
				)
				row.add_child(remove_btn)

			rows_box.add_child(row)

	rebuild.call()

	var add_btn := Button.new()
	add_btn.text = "Add Flag Rule"
	add_btn.pressed.connect(func():
		var new_key := "new_flag_%d" % flag_map.size()
		flag_map[new_key] = 0
		rebuild.call()
	)
	vb.add_child(add_btn)

	return vb

# ============================================================
# Deletion with automatic index remap (prevents self-loop /
# out-of-bounds corruption from a manual delete)
# ============================================================

func _delete_line_with_remap(lines_array: Array, delete_idx: int) -> void:
	lines_array.remove_at(delete_idx)
	for line in lines_array:
		if line.has("next"):
			line["next"] = _remap_index(line["next"], delete_idx)
		for choice in line.get("choices", []):
			if choice.has("next"):
				choice["next"] = _remap_index(choice["next"], delete_idx)
		if line.get("type", "") == "start_router":
			var fm: Dictionary = line.get("start_index_if_flag", {})
			for k in fm.keys():
				fm[k] = _remap_index(fm[k], delete_idx)
				if fm[k] == null:
					fm[k] = 0   # router target can't dangle -- fall back to line 0, re-check in Validate

## Inserting a router at index 0 shifts every existing line's real position
## by +1 -- every "next"/choice-next already in the file must shift +1 too,
## or this reproduces the exact self-loop corruption we hand-fixed earlier
## (a next/choice pointing at what is now the WRONG line after the shift).
func _insert_router_with_remap(lines_array: Array) -> void:
	for line in lines_array:
		if line.get("next") is int:
			line["next"] += 1
		for choice in line.get("choices", []):
			if choice.get("next") is int:
				choice["next"] += 1
	lines_array.insert(0, {"start_index_if_flag": {"default": 1}, "type": "start_router"})

func _remap_index(idx, delete_idx: int):
	if idx == null:
		return null
	if idx == delete_idx:
		return null   # was pointing at the deleted line -- now dangling, Validate will flag it
	if idx > delete_idx:
		return idx - 1
	return idx

# ============================================================
# Dialogue Scenes tab
# ============================================================

func _build_dialogue_tab() -> Control:
	var split := HSplitContainer.new()
	split.name = "Dialogue Scenes"

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	scene_list = ItemList.new()
	scene_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_list.item_selected.connect(_on_scene_selected)
	left.add_child(scene_list)
	var add_scene_btn := Button.new()
	add_scene_btn.text = "Add New Scene"
	add_scene_btn.pressed.connect(_on_add_scene_pressed)
	left.add_child(add_scene_btn)
	split.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_editor_box = VBoxContainer.new()
	scene_editor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scene_editor_box)
	split.add_child(scroll)

	return split

func _refresh_scene_list() -> void:
	scene_list.clear()
	for key in dialogue_data.keys():
		if not key.begins_with("idle_pool_"):
			scene_list.add_item(key)

func _on_add_scene_pressed() -> void:
	var new_key := "new_scene_%d" % dialogue_data.size()
	dialogue_data[new_key] = [
		{"start_index_if_flag": {"default": 1}, "type": "start_router"},
		{"speaker": "", "text": "", "next": null}
	]
	_refresh_scene_list()
	status_label.text = "Added '%s' -- rename via the JSON key manually if needed, or re-key later." % new_key

func _on_scene_selected(idx: int) -> void:
	current_scene_key = scene_list.get_item_text(idx)
	_rebuild_scene_editor()

func _rebuild_scene_editor() -> void:
	_clear(scene_editor_box)
	if current_scene_key.is_empty():
		return
	var lines: Array = dialogue_data[current_scene_key]

	var has_router: bool = not lines.is_empty() and lines[0].has("start_index_if_flag")
	if not has_router:
		var add_router_btn := Button.new()
		add_router_btn.text = "Add Router (lets this scene react to a flag on start)"
		add_router_btn.pressed.connect(func():
			_insert_router_with_remap(lines)
			_rebuild_scene_editor()
		)
		scene_editor_box.add_child(add_router_btn)

	for i in range(lines.size()):
		scene_editor_box.add_child(_build_line_row(lines[i], lines, i, true, _rebuild_scene_editor))

	var add_line_btn := Button.new()
	add_line_btn.text = "Add Line (appended at end)"
	add_line_btn.pressed.connect(func():
		lines.append({"speaker": "", "text": "", "next": null})
		_rebuild_scene_editor()
	)
	scene_editor_box.add_child(add_line_btn)

# ============================================================
# Idle Pools tab
# ============================================================

func _build_idle_tab() -> Control:
	var split := HSplitContainer.new()
	split.name = "Idle Pools"

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	pool_list = ItemList.new()
	pool_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pool_list.item_selected.connect(_on_pool_selected)
	left.add_child(pool_list)
	split.add_child(left)

	tier_tab = TabContainer.new()
	tier_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tier in TIER_KEYS + ["overrides"]:
		var scroll := ScrollContainer.new()
		scroll.name = tier.capitalize() if tier != "overrides" else "Flag Overrides"
		var box := VBoxContainer.new()
		scroll.add_child(box)
		tier_tab.add_child(scroll)
		tier_boxes[tier] = box
	split.add_child(tier_tab)

	return split

func _refresh_pool_list() -> void:
	pool_list.clear()
	for key in dialogue_data.keys():
		if key.begins_with("idle_pool_"):
			pool_list.add_item(key)

func _on_pool_selected(idx: int) -> void:
	current_pool_key = pool_list.get_item_text(idx)
	_rebuild_idle_editor()

func _rebuild_idle_editor() -> void:
	for tier in tier_boxes:
		_clear(tier_boxes[tier])
	if current_pool_key.is_empty():
		return
	var pool: Dictionary = dialogue_data[current_pool_key]

	for tier in TIER_KEYS:
		var lines: Array = pool.get(tier, [])
		pool[tier] = lines   # ensure key exists even if it didn't
		var box: VBoxContainer = tier_boxes[tier]
		for i in range(lines.size()):
			box.add_child(_build_line_row(lines[i], lines, i, false, _rebuild_idle_editor))
		var add_btn := Button.new()
		add_btn.text = "Add Line to %s tier" % tier
		add_btn.pressed.connect(func():
			lines.append({"speaker": "", "text": "", "word_ids": []})
			_rebuild_idle_editor()
		)
		box.add_child(add_btn)

	# Flag overrides -- each override is its own named bucket of idle lines,
	# checked before rapport tier (Comp_Dialogue._resolve_idle_bucket).
	var overrides: Dictionary = pool.get("flag_overrides", {})
	pool["flag_overrides"] = overrides
	var obox: VBoxContainer = tier_boxes["overrides"]
	obox.add_child(_label("Checked BEFORE rapport tier. First true flag wins."))
	for flag_id in overrides.keys():
		obox.add_child(_label("Flag: %s" % flag_id))
		var lines: Array = overrides[flag_id]
		for i in range(lines.size()):
			obox.add_child(_build_line_row(lines[i], lines, i, false, _rebuild_idle_editor))
		var add_line_btn := Button.new()
		add_line_btn.text = "Add Line to '%s' override" % flag_id
		add_line_btn.pressed.connect(func():
			lines.append({"speaker": "", "text": "", "word_ids": []})
			_rebuild_idle_editor()
		)
		obox.add_child(add_line_btn)
		var remove_override_btn := Button.new()
		remove_override_btn.text = "Remove '%s' override entirely" % flag_id
		remove_override_btn.pressed.connect(func():
			overrides.erase(flag_id)
			_rebuild_idle_editor()
		)
		obox.add_child(remove_override_btn)

	var new_override_row := HBoxContainer.new()
	var new_flag_edit := LineEdit.new()
	new_flag_edit.placeholder_text = "e.g. ch2_bakhawan_gate1_mastered"
	new_override_row.add_child(new_flag_edit)
	var add_override_btn := Button.new()
	add_override_btn.text = "Add New Flag Override"
	add_override_btn.pressed.connect(func():
		var fid: String = new_flag_edit.text.strip_edges()
		if not fid.is_empty() and not overrides.has(fid):
			overrides[fid] = [{"speaker": "", "text": "", "word_ids": []}]
			_rebuild_idle_editor()
	)
	new_override_row.add_child(add_override_btn)
	obox.add_child(new_override_row)

# ============================================================
# Challenges tab
# ============================================================

func _build_challenge_tab() -> Control:
	var split := HSplitContainer.new()
	split.name = "Challenges"

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	challenge_list = ItemList.new()
	challenge_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	challenge_list.item_selected.connect(_on_challenge_selected)
	left.add_child(challenge_list)
	var add_btn := Button.new()
	add_btn.text = "Add New Challenge"
	add_btn.pressed.connect(_on_add_challenge_pressed)
	left.add_child(add_btn)
	split.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_editor_box = VBoxContainer.new()
	scroll.add_child(challenge_editor_box)
	split.add_child(scroll)

	return split

func _refresh_challenge_list() -> void:
	challenge_list.clear()
	for key in challenge_data.keys():
		challenge_list.add_item(key)

func _on_add_challenge_pressed() -> void:
	var new_id := "new_challenge_%d" % challenge_data.size()
	challenge_data[new_id] = {
		"type": "mcq", "word_ids": [], "question": "",
		"choices": ["", "", ""], "correct_index": 0,
		"hint_on_wrong": "",
		"reward": {"stars": 0, "badge": "", "stamp": "", "memory_page": "", "hint_tokens": 0},
		"unlock_target": ""
	}
	_refresh_challenge_list()

func _on_challenge_selected(idx: int) -> void:
	current_challenge_id = challenge_list.get_item_text(idx)
	_rebuild_challenge_editor()

func _rebuild_challenge_editor() -> void:
	_clear(challenge_editor_box)
	if current_challenge_id.is_empty():
		return
	var c: Dictionary = challenge_data[current_challenge_id]

	var q_row := HBoxContainer.new()
	q_row.add_child(_label("Question:"))
	var q_edit := LineEdit.new()
	q_edit.text = c.get("question", "")
	q_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_edit.text_changed.connect(func(t): c["question"] = t)
	q_row.add_child(q_edit)
	challenge_editor_box.add_child(q_row)

	challenge_editor_box.add_child(_label("Choices (mark the correct one):"))
	var choices: Array = c.get("choices", [])
	var correct_group := ButtonGroup.new()
	for i in range(choices.size()):
		var row := HBoxContainer.new()
		var radio := CheckBox.new()
		radio.button_group = correct_group
		radio.button_pressed = (i == c.get("correct_index", -1))
		radio.pressed.connect(func(): c["correct_index"] = i)
		row.add_child(radio)
		var edit := LineEdit.new()
		edit.text = choices[i]
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(func(t): choices[i] = t)
		row.add_child(edit)
		var remove_btn := Button.new()
		remove_btn.text = "Remove"
		remove_btn.pressed.connect(func():
			choices.remove_at(i)
			if c.get("correct_index", 0) >= choices.size():
				c["correct_index"] = 0
			_rebuild_challenge_editor()
		)
		row.add_child(remove_btn)
		challenge_editor_box.add_child(row)
	var add_choice_btn := Button.new()
	add_choice_btn.text = "Add Choice"
	add_choice_btn.pressed.connect(func():
		choices.append("")
		_rebuild_challenge_editor()
	)
	challenge_editor_box.add_child(add_choice_btn)

	var hint_row := HBoxContainer.new()
	hint_row.add_child(_label("Hint on wrong:"))
	var hint_edit := LineEdit.new()
	hint_edit.text = c.get("hint_on_wrong", "")
	hint_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_edit.text_changed.connect(func(t): c["hint_on_wrong"] = t)
	hint_row.add_child(hint_edit)
	challenge_editor_box.add_child(hint_row)

	var word_row := HBoxContainer.new()
	word_row.add_child(_label("word_ids (comma-separated):"))
	var word_edit := LineEdit.new()
	word_edit.text = ",".join(c.get("word_ids", []))
	word_edit.text_changed.connect(func(t):
		var ids: Array = []
		for part in t.split(","):
			var trimmed: String = part.strip_edges()
			if not trimmed.is_empty():
				ids.append(trimmed)
		c["word_ids"] = ids
	)
	word_row.add_child(word_edit)
	challenge_editor_box.add_child(word_row)

	var target_row := HBoxContainer.new()
	target_row.add_child(_label("unlock_target:"))
	var target_edit := LineEdit.new()
	target_edit.text = c.get("unlock_target", "")
	target_edit.text_changed.connect(func(t): c["unlock_target"] = t)
	target_row.add_child(target_edit)
	var target_warn := _label("  ⚠ not in regions.json" if (not target_edit.text.is_empty() and not region_keys.has(target_edit.text)) else "")
	target_row.add_child(target_warn)
	target_edit.text_changed.connect(func(t):
		target_warn.text = "  ⚠ not in regions.json" if (not t.is_empty() and not region_keys.has(t)) else ""
	)
	challenge_editor_box.add_child(target_row)

	var reward: Dictionary = c.get("reward", {})
	c["reward"] = reward
	challenge_editor_box.add_child(_label("Reward:"))
	challenge_editor_box.add_child(_build_reward_row("stars (int)", reward, "stars"))
	challenge_editor_box.add_child(_build_reward_row("badge id", reward, "badge"))
	challenge_editor_box.add_child(_build_reward_row("stamp id", reward, "stamp"))
	challenge_editor_box.add_child(_build_reward_row("memory_page id (first-try only)", reward, "memory_page"))
	challenge_editor_box.add_child(_build_reward_row("hint_tokens (int)", reward, "hint_tokens"))

func _build_reward_row(label_text: String, reward: Dictionary, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_label(label_text + ":"))
	var edit := LineEdit.new()
	edit.text = str(reward.get(key, ""))
	edit.text_changed.connect(func(t):
		if key in ["stars", "hint_tokens"]:
			reward[key] = int(t) if t.is_valid_int() else 0
		else:
			reward[key] = t
	)
	row.add_child(edit)
	return row

# ============================================================
# Validation -- runs before Save, reused checks from the earlier
# batch-fix scripts (self-loop next, missing default, OOB targets,
# empty set_flag_on_enter, unknown word_ids, challenge correct_index,
# unlock_target vs regions.json)
# ============================================================

func _run_validation() -> void:
	_show_validation(_validate_all())

func _show_validation(issues: Array) -> void:
	if issues.is_empty():
		validation_log.text = "[color=green]All clean. Safe to Save.[/color]"
	else:
		var lines := ["[color=red]%d issue(s):[/color]" % issues.size()]
		for i in issues:
			lines.append(" - " + i)
		validation_log.text = "\n".join(lines)

func _validate_all() -> Array:
	var issues: Array = []
	for scene_key in dialogue_data.keys():
		var value = dialogue_data[scene_key]
		if not (value is Array):
			continue
		var lines: Array = value
		for i in range(lines.size()):
			var line = lines[i]
			if not (line is Dictionary):
				continue
			if line.get("type", "") == "start_router":
				if i != 0:
					issues.append("%s[%d]: router must be at index 0" % [scene_key, i])
				var fm: Dictionary = line.get("start_index_if_flag", {})
				if not fm.has("default"):
					issues.append("%s[%d]: router missing 'default'" % [scene_key, i])
				for fid in fm.keys():
					var tgt = fm[fid]
					if not (tgt is int) or tgt < 0 or tgt >= lines.size():
						issues.append("%s[%d]: flag '%s' target %s out of bounds" % [scene_key, i, fid, str(tgt)])
			if line.has("set_flag_on_enter") and String(line["set_flag_on_enter"]).is_empty():
				issues.append("%s[%d]: set_flag_on_enter is empty string, remove instead" % [scene_key, i])
			if line.get("next") is int and line["next"] == i:
				issues.append("%s[%d]: self-loop next" % [scene_key, i])
			if line.get("next") is int and (line["next"] < 0 or line["next"] > lines.size()):
				issues.append("%s[%d]: next out of bounds" % [scene_key, i])
			for wid in line.get("word_ids", []):
				if not word_bank_ids.has(wid):
					issues.append("%s[%d]: word_id '%s' not in word_bank.json" % [scene_key, i, wid])
			for choice in line.get("choices", []):
				if choice.get("next") is int and choice["next"] == i:
					issues.append("%s[%d]: choice self-loop" % [scene_key, i])
				if choice.get("next") is int and (choice["next"] < 0 or choice["next"] > lines.size()):
					issues.append("%s[%d]: choice next out of bounds" % [scene_key, i])

	for challenge_id in challenge_data.keys():
		var c: Dictionary = challenge_data[challenge_id]
		var choices: Array = c.get("choices", [])
		var ci = c.get("correct_index", -1)
		if not (ci is int) or ci < 0 or ci >= choices.size():
			issues.append("%s: correct_index out of bounds" % challenge_id)
		var target: String = c.get("unlock_target", "")
		if not target.is_empty() and not region_keys.has(target):
			issues.append("%s: unlock_target '%s' not in regions.json" % [challenge_id, target])

	return issues
