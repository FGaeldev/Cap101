# quests_panel.gd — Quests: list in the left column (Active, then Completed),
# details of the selected one in the right column. Quests come from
# QuestManager, world tasks from TaskManager, the same sources the HUD quest
# column reads.
extends "res://scripts/ui/menus/menu_panel.gd"

const MAIN_CATEGORY := "main"

var _list: VBoxContainer
var _detail: VBoxContainer
var _group: ButtonGroup
## Key of the selected entry ("quest:q003" / "task:id"), kept across opens.
var _selected_key: String = ""
var _entries: Array = []

func _init() -> void:
	super("Quests", true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	right.add_child(_detail)

func _on_show() -> void:
	_entries = _collect_entries()
	var keys: Array = _entries.map(func(e): return e["key"])
	if not _selected_key in keys:
		_selected_key = keys[0] if not keys.is_empty() else ""
	_rebuild_list()
	_show_detail()

## Active first (main quests on top), then completed. Quests not unlocked yet
## are left out so the list doesn't spoil the story.
func _collect_entries() -> Array:
	var active: Array = []
	var done: Array = []
	for qid in QuestManager.quests:
		var q: Dictionary = QuestManager.quests[qid]
		var completed: bool = GameState.get_flag(q.get("completion_flag", ""))
		var is_active: bool = qid in QuestManager.active_quests
		if not completed and not is_active:
			continue
		var entry := {
			"key": "quest:" + qid,
			"title": q.get("title", qid),
			"main": q.get("category", "") == MAIN_CATEGORY,
			"done": completed,
			"description": q.get("description", ""),
		}
		(done if completed else active).append(entry)
	for tid in TaskManager.get_active_task_ids():
		active.append(_task_entry(tid, false))
	for tid in GameState.completed_tasks:
		done.append(_task_entry(tid, true))
	active.sort_custom(func(a, b): return a["main"] and not b["main"])
	return active + done

func _task_entry(tid: String, done: bool) -> Dictionary:
	var def: Dictionary = TaskManager.task_defs.get(tid, {})
	return {
		"key": "task:" + tid,
		"title": TaskManager.get_task_title(tid),
		"main": false,
		"done": done,
		"description": def.get("description", ""),
		"giver": def.get("giver_npc", ""),
		"steps_done": TaskManager.get_step_count(tid) if done else int(GameState.active_tasks.get(tid, 0)),
		"steps_total": TaskManager.get_step_count(tid),
	}

func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_group = ButtonGroup.new()
	if _entries.is_empty():
		_list.add_child(MenuStyle.label("No quests yet.", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED))
		return
	var section := ""
	for entry in _entries:
		var entry_section: String = "Completed" if entry["done"] else "Active"
		if entry_section != section:
			section = entry_section
			_list.add_child(MenuStyle.label(section, UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS))
		var btn := MenuStyle.text_button(entry["title"],
				MenuStyle.ICON_DONE if entry["done"] else MenuStyle.ICON_ACTIVE, "secondary")
		if entry["done"]:
			MenuStyle.tint_button_icon(btn, MenuStyle.ICON_COLOR_DONE)
		btn.toggle_mode = true
		btn.button_group = _group
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
		btn.button_pressed = entry["key"] == _selected_key
		btn.pressed.connect(_on_entry_pressed.bind(entry["key"]))
		_list.add_child(btn)

func _on_entry_pressed(key: String) -> void:
	AudioManager.play_sfx("menu_click")
	_selected_key = key
	_show_detail()

func _show_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	var entry: Dictionary = {}
	for e in _entries:
		if e["key"] == _selected_key:
			entry = e
	if entry.is_empty():
		_detail.add_child(MenuStyle.label("Quests you pick up show here.", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DISABLED))
		return
	var title := MenuStyle.label(entry["title"], UIThemeApplier.FONT_SIZE_L, UIThemeApplier.TEXT_EMPHASIS)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(title)
	var kind: String = "Main quest" if entry["main"] else ("Task" if entry["key"].begins_with("task:") else "Side quest")
	_detail.add_child(MenuStyle.label("%s · %s" % [kind, "Completed" if entry["done"] else "Active"],
			UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DISABLED))
	if not str(entry.get("giver", "")).is_empty():
		_detail.add_child(MenuStyle.label("From " + entry["giver"], UIThemeApplier.FONT_SIZE_S))
	if not str(entry["description"]).is_empty():
		var desc := MenuStyle.label(entry["description"], UIThemeApplier.FONT_SIZE_S)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(desc)
	if entry.has("steps_total") and entry["steps_total"] > 0:
		_detail.add_child(MenuStyle.label("Steps done: %d / %d" % [entry["steps_done"], entry["steps_total"]],
				UIThemeApplier.FONT_SIZE_S))
