# HUD.gd
extends CanvasLayer

# Must keep processing while BookUI pauses the tree (BookUI sets
# get_tree().paused = true on open) -- otherwise _process below stops firing
# and joystick/menu/interact controls stay stuck visible under the book.
# Same reasoning as BookUI.gd's own PROCESS_MODE_ALWAYS.
const QUEST_BANNER_SCENE: PackedScene = preload("res://scenes/ui/quest_banner.tscn")

# Sibling CanvasLayers under Game.tscn's UILayer that count as "overlay
# active" -- fetched by name via get_parent(), not stored as scene refs,
# since HUD.tscn is instanced standalone (see hud.tscn) and only has these
# neighbors once placed under UILayer in Game.tscn.
const OVERLAY_SIBLINGS := ["QuestCompletePopup", "PuzzlePanel", "ChallengePanel"]

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var menu_button: Button = $MenuButton
@onready var joystick: Control = $VirtualJoystick
@onready var interact_button: Button = $InteractButton

var _nearest_interactable: InteractableComponent = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	UIThemeApplier.apply_button_theme(interact_button, "primary")
	interact_button.pressed.connect(_on_interact_button_pressed)

func _process(_delta: float) -> void:
	var overlay: bool = _is_overlay_active()
	# Controls hidden whenever any overlay (BookUI, dialogue, quest/challenge/
	# puzzle popups) is on screen -- player can't act through them anyway,
	# and a stray visible joystick/button over a popup reads as a bug.
	joystick.visible = not overlay
	menu_button.visible = not overlay
	_update_interact_button(overlay)

## Nearest in-range InteractableComponent, or null if none/overlay active.
## Button text mirrors that NPC/object's own interact_label (e.g. "Talk",
## "Examine") instead of a generic "Interact" for every target.
func _update_interact_button(overlay: bool) -> void:
	if overlay:
		interact_button.visible = false
		_nearest_interactable = null
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		interact_button.visible = false
		_nearest_interactable = null
		return
	_nearest_interactable = InteractableComponent.get_nearest(player.global_position)
	interact_button.visible = _nearest_interactable != null
	if _nearest_interactable:
		interact_button.text = _nearest_interactable.interact_label

func _on_interact_button_pressed() -> void:
	if is_instance_valid(_nearest_interactable):
		# Routes through the same guarded entry point keyboard/touch use
		# (Comp_Interactable.try_interact) -- no separate guard copy here.
		_nearest_interactable.try_interact()

## True if any overlay that should suppress movement controls is showing.
## BookUI/DialogueUI checked directly (autoloads, always addressable).
## Popup CanvasLayers are scene siblings under UILayer -- see OVERLAY_SIBLINGS.
func _is_overlay_active() -> bool:
	if BookUI.visible:
		return true
	if DialogueUI.is_active():
		return true
	if CutsceneManager.is_playing():
		return true
	var parent := get_parent()
	if parent == null:
		return false
	for sibling_name in OVERLAY_SIBLINGS:
		var node := parent.get_node_or_null(sibling_name)
		if node and node.visible:
			return true
	return false

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
