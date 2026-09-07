# HUD.gd
extends CanvasLayer

const QUEST_BANNER_SCENE: PackedScene = preload("res://scenes/ui/quest_banner.tscn")

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_list_changed)
	QuestManager.quest_completed.connect(_on_quest_list_changed)
	# World tasks (additive to quests, TDD Addendum WorldTask) render in the
	# same upper-left list — task_step_advanced carries 2 args, quest signals
	# carry 1, so it gets its own thin wrapper rather than sharing the slot.
	TaskManager.task_started.connect(_on_quest_list_changed)
	TaskManager.task_step_advanced.connect(_on_task_progress_changed)
	TaskManager.task_completed.connect(_on_quest_list_changed)
	_rebuild_quest_rows()
	UIThemeApplier.apply_icon_button_theme(menu_button, "menu")
	menu_button.pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed() -> void:
	# Mobile has no keyboard ui_cancel — this is the only way to reach
	# BookUI on a touch-only device (Android back button still works too,
	# via BackButtonBridge). Defaults to "settings" tab, same as ui_cancel.
	# No AudioManager.play_sfx() here — BookUI.open()/switch_tab() already
	# plays "menu_click" itself.
	BookUI.open()

func _on_quest_list_changed(_qid: String) -> void:
	_rebuild_quest_rows()

func _on_task_progress_changed(_task_id: String, _step_index: int) -> void:
	_rebuild_quest_rows()

## Rebuilds the VBoxContainer's quest rows from QuestManager.active_quests,
## plus active world-task rows from TaskManager (additive, TDD Addendum
## WorldTask) — same row style, "Task:" prefix + step progress distinguishes
## them from quest rows without a second UI system.
func _rebuild_quest_rows() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var quest_ids: Array = QuestManager.active_quests
	var task_ids: Array = TaskManager.get_active_task_ids()

	if quest_ids.is_empty() and task_ids.is_empty():
		_add_quest_row("", "Quest: —")
		return

	for qid in quest_ids:
		var q = QuestManager.quests.get(qid, {})
		_add_quest_row(qid, q.get("title", qid))

	for tid in task_ids:
		var completed_steps: int = GameState.active_tasks.get(tid, 0)
		var total_steps: int = TaskManager.get_step_count(tid)
		var title: String = TaskManager.get_task_title(tid)
		# completed_steps, not current_step+1 -- avoids the row reading "2/2"
		# (looks done) while the task is still active and the last step is
		# merely in progress. Row disappears entirely on true completion
		# instead (task leaves active_tasks), so "N/N" never displays here.
		_add_quest_row("task_%s" % tid, "Task: %s (%d/%d)" % [title, completed_steps, total_steps])

func _add_quest_row(qid: String, title_text: String) -> void:
	var row: PanelContainer = QUEST_BANNER_SCENE.instantiate()
	row.name = "QuestRow_%s" % (qid if qid != "" else "none")
	vbox.add_child(row)

	var label: Label = row.get_node("QuestLabel")
	label.text = title_text
	_style_row(row, label)

func _style_row(row: PanelContainer, label: Label) -> void:
	# Was flat navy box w/ hardcoded gold border — off the book/parchment
	# system entirely. Now matches BookUI chrome via UIThemeApplier.
	row.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
