# HUD.gd
extends CanvasLayer
# Layout (hud.tscn):
#   top-left  QuestColumn: MainQuest panel (current story objective) +
#             SubQuests rows (other active quests + world tasks)
#   top-right TopRight/RightColumn: Clock ("Mon 8:10 AM"), MenuButton, Toasts.
#             Own CanvasLayer (89): above dialogue/quiz panels so new-word
#             toasts show mid-conversation, below the tutorial overlay (90).
#   bottom    VirtualJoystick (left), InteractButton (right)
#
# Toasts: quest started/complete, achievement unlocked, new word. At most
# MAX_TOASTS on screen; the rest wait in _toast_queue. Replaces the old modal
# QuestCompletePopup and the separate WordReveal toast.

# Must keep processing while BookUI pauses the tree (BookUI sets
# get_tree().paused = true on open) -- otherwise _process below stops firing
# and joystick/menu/interact controls stay stuck visible under the book.
# Same reasoning as BookUI.gd's own PROCESS_MODE_ALWAYS.

# Sibling CanvasLayers under Game.tscn's UILayer that count as "overlay
# active" -- fetched by name via get_parent(), not stored as scene refs,
# since HUD.tscn is instanced standalone (see hud.tscn) and only has these
# neighbors once placed under UILayer in Game.tscn.
const OVERLAY_SIBLINGS := ["PuzzlePanel", "ChallengePanel"]

## Quests with "category": "main" in quest_data.json feed the MainQuest panel;
## anything else (or a missing category) is a sub quest.
const MAIN_CATEGORY := "main"
## Sub-quest rows shown before collapsing the rest into "+N more".
const MAX_SUB_ROWS := 3

const MAX_TOASTS := 2
## Fallback toast body width (px) if the word bank is empty.
const TOAST_FALLBACK_WIDTH := 100.0
## Small "New Word" / "Quest Complete" header above the toast body.
const TOAST_KIND_FONT_SIZE := 10
const TOAST_HOLD := 3.0
const TOAST_FADE := 0.25

@onready var main_quest: PanelContainer = $QuestColumn/MainQuest
@onready var main_quest_title: Label = $QuestColumn/MainQuest/VBox/Title
@onready var sub_quests: VBoxContainer = $QuestColumn/SubQuests
@onready var clock_panel: PanelContainer = $TopRight/RightColumn/Clock
@onready var clock_label: Label = $TopRight/RightColumn/Clock/Label
@onready var menu_button: Button = $TopRight/RightColumn/MenuButton
@onready var toasts: VBoxContainer = $TopRight/RightColumn/Toasts
@onready var joystick: Control = $VirtualJoystick
@onready var interact_button: Button = $InteractButton

var _nearest_interactable: InteractableComponent = null
## Pending toasts: [{kind: String, text: String}].
var _toast_queue: Array = []
var _toasts_showing: int = 0
## Toast body width: the widest Akeanon word in the word bank. Measured once.
var _toast_width: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	QuestManager.quest_started.connect(_on_quest_started)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.quest_list_changed.connect(_rebuild_quest_rows)
	# World tasks (additive to quests, TDD Addendum WorldTask) render as sub
	# quests. task_step_advanced carries 2 args, the others 1.
	TaskManager.task_started.connect(func(_tid): _rebuild_quest_rows())
	TaskManager.task_step_advanced.connect(func(_tid, _step): _rebuild_quest_rows())
	TaskManager.task_completed.connect(func(_tid): _rebuild_quest_rows())
	GameState.word_learned.connect(_on_word_learned)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	_apply_style()
	_rebuild_quest_rows()
	UIThemeApplier.apply_icon_button_theme(menu_button, "menu")
	menu_button.pressed.connect(_on_menu_button_pressed)
	UIThemeApplier.apply_icon_button_theme(interact_button, "dictionary")
	interact_button.pressed.connect(_on_interact_button_pressed)
	TutorialManager.register_target("joystick", joystick)
	TutorialManager.register_target("interact_button", interact_button)

func _process(_delta: float) -> void:
	var overlay: bool = _is_overlay_active()
	# Controls hidden whenever any overlay (BookUI, dialogue, quest/challenge/
	# puzzle popups) is on screen -- player can't act through them anyway,
	# and a stray visible joystick/button over a popup reads as a bug.
	# The menu button is the exception: always shown, so the Book is always
	# reachable on touch devices (BookUI itself draws over it when open).
	joystick.visible = not overlay
	_update_interact_button(overlay)
	var clock_text: String = DayNightManager.format_clock()
	if clock_label.text != clock_text:
		clock_label.text = clock_text

func _apply_style() -> void:
	for panel in [main_quest, clock_panel]:
		panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	main_quest_title.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	main_quest_title.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	clock_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	clock_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)

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

# --- Quests -----------------------------------------------------------------

func _on_quest_started(quest_id: String) -> void:
	_rebuild_quest_rows()
	var q: Dictionary = QuestManager.quests.get(quest_id, {})
	if q.get("show_popup", true):
		push_toast("New Quest", q.get("title", quest_id))

## Utility/tutorial quests opt out of toasts with "show_popup": false.
func _on_quest_completed(quest_id: String) -> void:
	_rebuild_quest_rows()
	var q: Dictionary = QuestManager.quests.get(quest_id, {})
	if q.get("show_popup", true):
		push_toast("Quest Complete", q.get("title", quest_id))

## Main panel = first active "main" quest in quest_data.json order (the
## current story objective). Every other active quest, then each active world
## task ("title (done/total)"), becomes a sub-quest row.
func _rebuild_quest_rows() -> void:
	for child in sub_quests.get_children():
		child.queue_free()

	var main_title: String = ""
	var sub_titles: Array[String] = []
	for qid in QuestManager.quests:
		if not qid in QuestManager.active_quests:
			continue
		var q: Dictionary = QuestManager.quests[qid]
		var title: String = q.get("title", qid)
		if main_title.is_empty() and q.get("category", "") == MAIN_CATEGORY:
			main_title = title
		else:
			sub_titles.append(title)

	for tid in TaskManager.get_active_task_ids():
		# completed_steps, not current_step+1 -- avoids the row reading "2/2"
		# (looks done) while the last step is merely in progress. The row
		# disappears on true completion (task leaves active_tasks).
		var completed_steps: int = GameState.active_tasks.get(tid, 0)
		var total_steps: int = TaskManager.get_step_count(tid)
		sub_titles.append("%s (%d/%d)" % [TaskManager.get_task_title(tid), completed_steps, total_steps])

	main_quest.visible = not main_title.is_empty()
	main_quest_title.text = main_title

	for i in mini(sub_titles.size(), MAX_SUB_ROWS):
		_add_sub_row(sub_titles[i])
	if sub_titles.size() > MAX_SUB_ROWS:
		_add_sub_row("+%d more" % (sub_titles.size() - MAX_SUB_ROWS))

func _add_sub_row(text: String) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	row.add_child(label)
	sub_quests.add_child(row)

# --- Toasts -----------------------------------------------------------------

## Word only (the gloss lives in the Dictionary); tapping opens its entry.
func _on_word_learned(word_id: String, akeanon: String, _gloss: String) -> void:
	push_toast("New Word", akeanon, BookUI.open_dictionary_entry.bind(word_id))

func _on_achievement_unlocked(ach: Dictionary) -> void:
	push_toast("Achievement", ach.get("title", ach.get("id", "")))

## Queues a toast. `kind` is the small header ("New Word"), `text` the body.
## Optional on_tap runs (and dismisses the toast) when the player taps it.
func push_toast(kind: String, text: String, on_tap: Callable = Callable()) -> void:
	_toast_queue.append({"kind": kind, "text": text, "on_tap": on_tap})
	_pump_toasts()

func _pump_toasts() -> void:
	while _toasts_showing < MAX_TOASTS and not _toast_queue.is_empty():
		_show_toast(_toast_queue.pop_front())

func _show_toast(entry: Dictionary) -> void:
	_toasts_showing += 1
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", -2)
	panel.add_child(vbox)
	var kind := Label.new()
	kind.text = entry["kind"]
	kind.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	kind.add_theme_font_size_override("font_size", TOAST_KIND_FONT_SIZE)
	vbox.add_child(kind)
	var body := Label.new()
	body.text = entry["text"]
	body.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	body.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	vbox.add_child(body)
	# Every toast is exactly _toast_width wide (the longest word fits on one
	# line); longer text such as quest titles is cut with "...".
	body.clip_text = true
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.custom_minimum_size.x = _get_toast_width()
	panel.modulate.a = 0.0
	toasts.add_child(panel)

	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, TOAST_FADE)
	tween.tween_interval(TOAST_HOLD)
	tween.tween_property(panel, "modulate:a", 0.0, TOAST_FADE)
	tween.finished.connect(_dismiss_toast.bind(panel, tween))

	var on_tap: Callable = entry["on_tap"]
	if on_tap.is_valid():
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.gui_input.connect(func(event: InputEvent):
			var tapped: bool = (event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT) \
					or (event is InputEventScreenTouch and event.pressed)
			if tapped and is_instance_valid(panel):
				panel.accept_event()
				_dismiss_toast(panel, tween)
				on_tap.call())
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Frees a toast (timer end or tap) and lets the next queued one in. Safe to
## call twice: only the first call for a panel counts.
func _dismiss_toast(panel: PanelContainer, tween: Tween) -> void:
	if not is_instance_valid(panel) or panel.is_queued_for_deletion():
		return
	if tween.is_valid():
		tween.kill()
	panel.queue_free()
	_toasts_showing -= 1
	_pump_toasts()

## Width of the widest Akeanon word in WordBank at the toast body font size,
## so a new-word toast never wraps and every toast shares one width. Measured
## with clock_label's font (already in the tree, so it has the project theme).
func _get_toast_width() -> float:
	if _toast_width >= 0.0:
		return _toast_width
	var font: Font = clock_label.get_theme_font("font")
	_toast_width = 0.0
	for word_data in WordBank.words.values():
		var akeanon: String = word_data.get("akeanon", "")
		_toast_width = maxf(_toast_width, font.get_string_size(
				akeanon, HORIZONTAL_ALIGNMENT_LEFT, -1, UIThemeApplier.FONT_SIZE_S).x)
	if _toast_width <= 0.0:
		_toast_width = TOAST_FALLBACK_WIDTH
	_toast_width = ceilf(_toast_width)
	return _toast_width
