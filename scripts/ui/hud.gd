# HUD.gd
extends CanvasLayer
# Layout (hud.tscn):
#   top-mid   TierBar: learning tier and progress to the next one (GameState)
#   top-left  QuestColumn: MainQuest panel (current story objective) +
#             SubQuests rows (other active quests + world tasks)
#   top-right TopRight/RightColumn: Clock ("Mon 8:10 AM"), MenuButton, Toasts.
#             Own CanvasLayer (89): above dialogue/quiz panels so new-word
#             toasts show mid-conversation, below the tutorial overlay (90).
#   bottom    VirtualJoystick (left), InteractButton (right)
#
# Toasts: quest started/complete, achievement unlocked, new word, upcoming
# event. At most MAX_TOASTS on screen; the rest wait in _toast_queue. Replaces
# the old modal QuestCompletePopup and the separate WordReveal toast.
#
# Separated menus (BookUI.separate_menus, Dev menu switch) change the HUD:
#   - Map and Dictionary buttons join the menu button in one row
#   - tapping the clock opens the Calendar, tapping the quest panel opens Quests
#   - one side-quest row instead of three plus "+N more"
#   - the TierBar hides; a progress toast at the top of the toast column fills
#     in place when progress goes up, then fades
# Book mode keeps the original HUD. Code for this is marked "separated menus".

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
## How far the joystick ring reaches past the control, for the tutorial arrow.
const JOYSTICK_RING_MARGIN: float = 42.0
## Sub-quest rows shown before collapsing the rest into "+N more".
const MAX_SUB_ROWS := 3

const MAX_TOASTS := 2
## Fallback toast body width (px) if the word bank is empty.
const TOAST_FALLBACK_WIDTH := 100.0
## Small "New Word" / "Quest Complete" header above the toast body.
const TOAST_KIND_FONT_SIZE := 10
const TOAST_HOLD := 3.0
const TOAST_FADE := 0.25

@onready var quest_column: VBoxContainer = $QuestColumn
@onready var main_quest: PanelContainer = $QuestColumn/MainQuest
@onready var main_quest_title: Label = $QuestColumn/MainQuest/VBox/Title
@onready var sub_quests: VBoxContainer = $QuestColumn/SubQuests
## Top of the right column (hud.tscn), and its top during full-screen panels: toasts
## sit below the panels' Quit and Check buttons.
const DEFAULT_COLUMN_TOP: float = 14.0
const FULLSCREEN_COLUMN_TOP: float = 38.0

@onready var right_column: VBoxContainer = $TopRight/RightColumn
@onready var clock_panel: PanelContainer = $TopRight/RightColumn/Clock
@onready var clock_label: Label = $TopRight/RightColumn/Clock/Label
@onready var menu_button: Button = $TopRight/RightColumn/MenuButton
@onready var toasts: VBoxContainer = $TopRight/RightColumn/Toasts
@onready var tier_bar: PanelContainer = $TierBar
@onready var tier_label: Label = $TierBar/Row/Label
@onready var tier_fill: ProgressBar = $TierBar/Row/Fill
@onready var joystick: Control = $VirtualJoystick
@onready var interact_button: Button = $InteractButton
## The D-pad alternative to the joystick (Settings > Movement controls). Built in
## code; it sits in the bottom-left corner, near where the joystick is.
var dpad: Control = null
const DPadScript := preload("res://scripts/ui/dpad.gd")
## D-pad size.
## Each key is 3/4 of a 1/3 cell of the art (24 of 32 px), so 128 makes every key
## 32 px, the size of the HUD menu buttons (MENU_BUTTON_SIZE).
const DPAD_SIZE: float = 128.0
## Gap between the D-pad and the screen's left and bottom edges (the interact
## key uses the same gap on the right, set in hud.tscn).
const DPAD_MARGIN: float = 20.0

# -- separated menus --
const MenuStyle := preload("res://scripts/ui/menus/menu_style.gd")
## HUD button size with the separated menus (book mode keeps the scene's 18px).
## hud_btns.png frame size: its 4px border leaves the 24px icon unscaled.
const MENU_BUTTON_SIZE := 32.0
const BOOK_MENU_BUTTON_SIZE := 18.0
## Half the icon sheet's 24px, so the pixels stay even.
const CLOCK_ICON_SIZE := 12
## completion_trigger of quests finished by opening the Dictionary (quest_data.json).
const DICTIONARY_QUEST_TRIGGER := "dictionary_opened"
## The Map button stays hidden until Rose hands over her map at the cathedral
## (Chapter 2). The tour flag covers saves from before that flag existed.
const MAP_UNLOCK_FLAGS: Array[String] = ["got_kalibo_map", "chapter2_tour_done"]
## Side-quest rows under the main quest with the separated menus.
const SEPARATE_SUB_ROWS := 1
## Seconds the progress toast stays after the last change (longer on a new tier).
const TIER_TOAST_HOLD := 3.5
const TIER_TOAST_TIER_UP_HOLD := 5.0
var _menu_row: HBoxContainer
var _dictionary_button: Button
var _map_button: Button
## Separated mode's menu button (hamburger icon); the scene's MenuButton keeps
## the book look and is hidden meanwhile.
var _pause_button: Button
## Separated mode: sun (AM) or moon (PM) after the time, in place of the text suffix.
var _clock_period: TextureRect
var _tier_toast: PanelContainer
var _tier_toast_kind: Label
var _tier_toast_label: Label
var _tier_toast_bar: ProgressBar
## Time.get_ticks_msec() after which the progress toast fades.
var _tier_toast_until: int = 0
var _tier_toast_fading: bool = false
var _book_clock_filter: Control.MouseFilter
var _book_quest_filter: Control.MouseFilter

# -- event reminders --
const CalendarUtil := preload("res://scripts/util/calendar_util.gd")
const InstructionsPanel := preload("res://scripts/ui/instructions_panel.gd")
const InteractKey := preload("res://scripts/ui/interact_key.gd")
## In-game hour the daily reminder shows ("every morning").
const REMINDER_HOUR := 6
## Reminders start this many days before an event, then daily until the day.
const REMINDER_DAYS_AHEAD := 3

var _nearest_interactable: InteractableComponent = null
## Pending toasts: [{kind: String, text: String}].
var _toast_queue: Array = []
var _toasts_showing: int = 0
## Tier the bar shows, for spotting a tier up.
var _shown_tier: int = 0
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
	GameState.mastery_changed.connect(_on_mastery_changed)
	GameState.word_learned.connect(_on_word_learned)
	AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)
	RewardManager.popup_queued.connect(_on_reward_popup)
	GameState.pesos_changed.connect(func(_total, _delta): _refresh_wallet())
	_apply_style()
	_refresh_tier()
	_build_wallet()
	_refresh_wallet()
	_build_fast_forward()
	_rebuild_quest_rows()
	# This layer sits above every panel: the column's own empty area must not
	# swallow clicks meant for what's under it. MenuButton still gets its own.
	right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIThemeApplier.apply_icon_button_theme(menu_button, "menu")
	menu_button.pressed.connect(_on_menu_button_pressed)
	# Drawn like the D-pad keys; the icon follows what pressing it would do.
	interact_button.text = ""
	interact_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interact_button.focus_mode = Control.FOCUS_NONE
	_set_interact_icon("talk")
	interact_button.pressed.connect(_on_interact_button_pressed)
	TutorialManager.register_target("quest_hud", main_quest)
	TutorialManager.register_target("tier_bar", tier_bar)
	# The joystick draws its ring well outside its small control rect.
	joystick.set_meta("tutorial_arrow_margin", JOYSTICK_RING_MARGIN)
	# Taps on the ring must not reach world objects under it (Comp_Interactable).
	joystick.add_to_group(InteractableComponent.TOUCH_BLOCKER_GROUP)
	_build_dpad()
	Accessibility.changed.connect(_apply_movement_controls)
	_apply_movement_controls()
	TutorialManager.register_target("interact_button", interact_button)
	_build_separated_menu_controls()
	BookUI.separate_menus_changed.connect(_apply_menu_mode)
	_apply_menu_mode(BookUI.separate_menus)
	DayNightManager.hour_changed.connect(func(_h): _check_event_reminders())
	_check_event_reminders.call_deferred()  # loaded save: this morning's may be due
	RewardManager.check_allowance.call_deferred()  # loaded save: this morning's allowance may be due
	# A save that finished the story before the "story so far" note existed.
	ChapterCard.show_note_on_load.call_deferred("story_so_far")

## The D-pad in the bottom-left corner, hidden until chosen.
func _build_dpad() -> void:
	dpad = DPadScript.new()
	dpad.name = "DPad"
	# Tucked into the bottom-left corner (not the joystick's spot, which needs
	# room for its ring), so the thumb rests near the screen edge.
	var center: Vector2 = Vector2(DPAD_MARGIN + DPAD_SIZE / 2.0, -(DPAD_MARGIN + DPAD_SIZE / 2.0))
	dpad.anchor_top = 1.0
	dpad.anchor_bottom = 1.0
	dpad.offset_left = center.x - DPAD_SIZE / 2.0
	dpad.offset_right = center.x + DPAD_SIZE / 2.0
	dpad.offset_top = center.y - DPAD_SIZE / 2.0
	dpad.offset_bottom = center.y + DPAD_SIZE / 2.0
	dpad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dpad.visible = false
	# Taps on the pad must not reach world objects under it (Comp_Interactable).
	dpad.add_to_group(InteractableComponent.TOUCH_BLOCKER_GROUP)
	add_child(dpad)
	move_child(dpad, joystick.get_index() + 1)

## Shows the chosen movement control; the tutorial's "move" arrow points at it.
func _apply_movement_controls() -> void:
	var active: Control = dpad if Accessibility.uses_dpad() else joystick
	TutorialManager.register_target("joystick", active)

func _process(_delta: float) -> void:
	var overlay: bool = _is_overlay_active()
	# Controls hidden whenever any overlay (BookUI, dialogue, quest/challenge/
	# puzzle popups) is on screen -- player can't act through them anyway,
	# and a stray visible joystick/button over a popup reads as a bug.
	# The menu button is the exception: always shown, so the Book is always
	# reachable on touch devices (BookUI itself draws over it when open).
	var use_dpad: bool = Accessibility.uses_dpad()
	joystick.visible = not overlay and not use_dpad
	dpad.visible = not overlay and use_dpad
	_update_interact_button(overlay)
	# Full-screen panels (newspaper, crossword, word search) have their own exit
	# and need the corners HUD draws in. Toasts stay, so new words still show.
	var fullscreen: bool = DialogueUI.is_fullscreen_active()
	toasts.visible = not DialogueUI.hides_toasts()  # queued toasts show once it closes
	clock_panel.visible = not fullscreen
	_wallet_panel.visible = not fullscreen and _wallet_shown()
	# First time the wallet is up with nothing else on screen: explain money.
	if _wallet_panel.visible and not overlay and not CutsceneManager.is_playing() \
			and not TutorialManager.is_done("money"):
		TutorialManager.start("money")
	_update_fast_forward(fullscreen)
	_menu_row.visible = not fullscreen
	quest_column.visible = not fullscreen
	tier_bar.visible = not fullscreen and not BookUI.separate_menus
	if BookUI.separate_menus:
		# Dictionary stays hidden until there's a first word, like the book's tab lock.
		# (Also shown while a quest waits on opening it: q002 in Chapter 1.)
		_dictionary_button.visible = not GameState.word_exposures.is_empty() \
				or QuestManager.has_active_trigger(DICTIONARY_QUEST_TRIGGER)
		_map_button.visible = _map_unlocked()
		_update_tier_toast()
	var column_top: float = FULLSCREEN_COLUMN_TOP if fullscreen else DEFAULT_COLUMN_TOP
	if right_column.offset_top != column_top:
		right_column.offset_top = column_top
	var clock_text: String = DayNightManager.format_clock()
	if BookUI.separate_menus:
		_update_clock_period()
		clock_text = clock_text.trim_suffix(" AM").trim_suffix(" PM")
	if clock_label.text != clock_text:
		clock_label.text = clock_text

func _apply_style() -> void:
	main_quest.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	clock_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_right_style())
	tier_bar.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	tier_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	tier_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	tier_fill.add_theme_stylebox_override("background", _make_tier_style(UIThemeApplier.TEXT_EMPHASIS))
	tier_fill.add_theme_stylebox_override("fill", _make_tier_style(UIThemeApplier.COLOR_SUCCESS))
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
	_nearest_interactable = InteractableComponent.get_nearest_to(player)
	interact_button.visible = _nearest_interactable != null
	if _nearest_interactable != null:
		_set_interact_icon(InteractKey.icon_for(str(_nearest_interactable.interact_label)))

## Current interact key icon (InteractKey.ICONS key), so styles only change on a new target.
var _interact_icon: String = ""

func _set_interact_icon(icon: String) -> void:
	if icon == _interact_icon:
		return
	_interact_icon = icon
	for state: String in ["normal", "hover", "focus", "disabled"]:
		interact_button.add_theme_stylebox_override(state, _key_style(InteractKey.texture(icon)))
	interact_button.add_theme_stylebox_override("pressed", _key_style(InteractKey.texture(icon, true)))

func _key_style(tex: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	return style

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
		push_toast("New Quest", QuestManager.get_title(quest_id))

## Utility/tutorial quests opt out of toasts with "show_popup": false.
func _on_quest_completed(quest_id: String) -> void:
	_rebuild_quest_rows()
	var q: Dictionary = QuestManager.quests.get(quest_id, {})
	if q.get("show_popup", true):
		push_toast("Quest Complete", QuestManager.get_title(quest_id))

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
		var title: String = QuestManager.get_title(qid)
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

	# separated menus: the full list is one tap away on the Quests panel.
	if BookUI.separate_menus:
		for i in mini(sub_titles.size(), SEPARATE_SUB_ROWS):
			_add_sub_row(sub_titles[i])
		return
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
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_right_style())
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

# --- Tier bar ---------------------------------------------------------------

func _make_tier_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style

func _on_mastery_changed() -> void:
	_refresh_tier()
	TutorialManager.start("tier_bar")

func _refresh_tier() -> void:
	var tier: int = GameState.get_difficulty_tier()
	tier_label.text = "Tier %d" % tier
	tier_fill.value = GameState.get_tier_progress()
	var tier_up: bool = _shown_tier > 0 and tier > _shown_tier
	var announce: bool = _shown_tier > 0  # not on the first fill in _ready()
	_shown_tier = tier
	# separated menus: the progress toast shows the change instead.
	if BookUI.separate_menus:
		if announce and _tier_toast != null:
			_show_tier_toast(tier, tier_up)
		return
	if tier_up:
		push_toast("Tier Up", "Tier %d" % tier)

# --- Separated menus ----------------------------------------------------------

## Builds the extra HUD controls once; _apply_menu_mode() shows or hides them.
func _build_separated_menu_controls() -> void:
	# [Map] [Dictionary] [Menu] row where the menu button was.
	_menu_row = HBoxContainer.new()
	_menu_row.name = "MenuRow"
	_menu_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_menu_row.add_theme_constant_override("separation", 4)
	_menu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: int = menu_button.get_index()
	right_column.remove_child(menu_button)
	right_column.add_child(_menu_row)
	right_column.move_child(_menu_row, index)

	_map_button = MenuStyle.hud_button(MenuStyle.ICON_MAP)
	_map_button.name = "MapButton"
	_map_button.pressed.connect(func(): BookUI.open("map"))
	_menu_row.add_child(_map_button)

	_dictionary_button = MenuStyle.hud_button(MenuStyle.ICON_DICTIONARY)
	_dictionary_button.name = "DictionaryButton"
	_dictionary_button.pressed.connect(func(): BookUI.open("dictionary"))
	_menu_row.add_child(_dictionary_button)

	_menu_row.add_child(menu_button)

	_pause_button = MenuStyle.hud_button(MenuStyle.ICON_MENU)
	_pause_button.name = "PauseButton"
	_pause_button.pressed.connect(_on_menu_button_pressed)
	_menu_row.add_child(_pause_button)

	# Clock row: time then sun/moon. Tapping the clock opens the calendar.
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 3)
	clock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_panel.remove_child(clock_label)
	clock_panel.add_child(clock_row)
	clock_row.add_child(clock_label)
	_clock_period = MenuStyle.icon_rect(MenuStyle.ICON_DAY, MenuStyle.ICON_COLOR_DAY, CLOCK_ICON_SIZE)
	clock_row.add_child(_clock_period)
	_book_clock_filter = clock_panel.mouse_filter
	_book_quest_filter = main_quest.mouse_filter
	clock_panel.gui_input.connect(_on_tap.bind(func(): BookUI.open("calendar")))
	main_quest.gui_input.connect(_on_tap.bind(func(): BookUI.open("bucket_list")))

	# Highlight targets for tutorials (data/tutorials/tutorials.json).
	TutorialManager.register_target("hud_map", _map_button)
	TutorialManager.register_target("hud_dictionary", _dictionary_button)
	TutorialManager.register_target("hud_pause", _pause_button)
	TutorialManager.register_target("hud_clock", clock_panel)
	# The menu buttons sit right under the clock; an arrow there would look
	# like it points at Dictionary.
	clock_panel.set_meta("tutorial_arrow_side", "left")

	# Progress toast: always the top toast, updated in place, not queued.
	_tier_toast = PanelContainer.new()
	_tier_toast.name = "TierToast"
	_tier_toast.size_flags_horizontal = Control.SIZE_SHRINK_END
	_tier_toast.add_theme_stylebox_override("panel", UIThemeApplier.make_header_right_style())
	_tier_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tier_toast.visible = false
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_tier_toast.add_child(vbox)
	_tier_toast_kind = MenuStyle.label("Progress", TOAST_KIND_FONT_SIZE, UIThemeApplier.TEXT_DISABLED)
	vbox.add_child(_tier_toast_kind)
	_tier_toast_label = MenuStyle.label("", UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_EMPHASIS)
	vbox.add_child(_tier_toast_label)
	_tier_toast_bar = MenuStyle.tier_bar()
	_tier_toast_bar.custom_minimum_size.x = _get_toast_width()
	vbox.add_child(_tier_toast_bar)
	toasts.add_child(_tier_toast)
	toasts.move_child(_tier_toast, 0)

func _map_unlocked() -> bool:
	if GameState.dev_mode:
		return true
	for flag: String in MAP_UNLOCK_FLAGS:
		if GameState.get_flag(flag):
			return true
	return false

## Shows/hides everything that differs between book mode and separated menus.
func _apply_menu_mode(enabled: bool) -> void:
	_map_button.visible = enabled and _map_unlocked()
	_dictionary_button.visible = enabled
	_clock_period.visible = enabled
	clock_label.text = ""  # next _process rewrites it with or without AM/PM
	_pause_button.visible = enabled
	menu_button.visible = not enabled
	for btn: Button in [_map_button, _dictionary_button, _pause_button]:
		btn.custom_minimum_size = Vector2(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
		btn.custom_maximum_size = Vector2(MENU_BUTTON_SIZE, MENU_BUTTON_SIZE)
	menu_button.custom_minimum_size = Vector2(BOOK_MENU_BUTTON_SIZE, BOOK_MENU_BUTTON_SIZE)
	menu_button.custom_maximum_size = Vector2(BOOK_MENU_BUTTON_SIZE, BOOK_MENU_BUTTON_SIZE)
	# Book mode: the scene's own mouse settings (taps are ignored in _on_tap).
	clock_panel.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else _book_clock_filter
	main_quest.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else _book_quest_filter
	var cursor := Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	clock_panel.mouse_default_cursor_shape = cursor
	main_quest.mouse_default_cursor_shape = cursor
	if not enabled:
		_tier_toast.visible = false
	# The tier tutorial points at whichever tier readout is on screen.
	TutorialManager.register_target("tier_bar", _tier_toast if enabled else tier_bar)
	_rebuild_quest_rows()

## Left click / touch on a non-button Control (clock, quest panel).
func _on_tap(event: InputEvent, action: Callable) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if tapped and BookUI.separate_menus:
		get_viewport().set_input_as_handled()
		action.call()

func _show_tier_toast(tier: int, tier_up: bool) -> void:
	_tier_toast_kind.text = "New tier" if tier_up else "Progress"
	_tier_toast_label.text = ("Tier %d reached" if tier_up else "Tier %d") % tier
	_tier_toast_bar.value = GameState.get_tier_progress()
	_tier_toast.visible = true
	_tier_toast.modulate.a = 1.0
	_tier_toast_fading = false
	var hold: float = TIER_TOAST_TIER_UP_HOLD if tier_up else TIER_TOAST_HOLD
	_tier_toast_until = Time.get_ticks_msec() + int(hold * 1000.0)

## Fades the progress toast once its hold is over, unless the tier tutorial
## is still pointing at it.
func _update_tier_toast() -> void:
	if not _tier_toast.visible or _tier_toast_fading:
		return
	if TutorialManager.active_id() == "tier_bar":
		_tier_toast_until = Time.get_ticks_msec() + int(TIER_TOAST_HOLD * 1000.0)
		return
	if Time.get_ticks_msec() < _tier_toast_until:
		return
	_tier_toast_fading = true
	var tween := create_tween()
	tween.tween_property(_tier_toast, "modulate:a", 0.0, TOAST_FADE)
	tween.finished.connect(func():
		if _tier_toast_fading:
			_tier_toast.visible = false
			_tier_toast_fading = false)

# --- Event reminders ----------------------------------------------------------

## Once per in-game day, from REMINDER_HOUR on: a toast for every event marked
## "remind": true in data/calendar_events.json that is 0..REMINDER_DAYS_AHEAD
## days away. GameState.event_reminder_date stops it repeating that day,
## across saves too.
func _check_event_reminders() -> void:
	if int(GameState.time_of_day) < REMINDER_HOUR:
		return
	if GameState.event_reminder_date == GameState.date_unix:
		return
	GameState.event_reminder_date = GameState.date_unix
	var upcoming: Array = []  # [{title, days}]
	for days in range(REMINDER_DAYS_AHEAD + 1):
		var date: Dictionary = Time.get_date_dict_from_unix_time(
				GameState.date_unix + days * DayNightManager.SECONDS_PER_DAY)
		for entry in CalendarUtil.events_in_month(date["year"], date["month"]):
			if entry["day"] == date["day"] and entry["event"].get("remind", false):
				upcoming.append({"title": entry["event"].get("title", ""), "days": days})
	if upcoming.is_empty():
		return
	var open_calendar := func(): BookUI.open("calendar")
	if upcoming.size() > 1:
		push_toast("Coming up", "%d events" % upcoming.size(), open_calendar)
		return
	var days_left: int = upcoming[0]["days"]
	var kind: String = "Today" if days_left == 0 else ("Tomorrow" if days_left == 1 else "In %d days" % days_left)
	push_toast(kind, upcoming[0]["title"], open_calendar)

## Sun before noon, moon after, matching the AM/PM it replaces.
func _update_clock_period() -> void:
	var morning: bool = GameState.time_of_day < 12.0
	var index: int = MenuStyle.ICON_DAY if morning else MenuStyle.ICON_NIGHT
	if _clock_period.texture != MenuStyle.icon(index):
		_clock_period.texture = MenuStyle.icon(index)
		_clock_period.self_modulate = MenuStyle.ICON_COLOR_DAY if morning else MenuStyle.ICON_COLOR_NIGHT

# --- Wallet (docs/ECONOMY_PLAN.md) -------------------------------------------

## Wallet counter: shown once the player lives in Aklan, or holds any money.
const WALLET_FLAG := "seen_chapter2_scene0"
var _wallet_panel: PanelContainer
var _wallet_label: Label

## "₱12" panel to the left of the clock, in one row with it.
func _build_wallet() -> void:
	var row := HBoxContainer.new()
	row.name = "ClockRow"
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: int = clock_panel.get_index()
	right_column.remove_child(clock_panel)
	right_column.add_child(row)
	right_column.move_child(row, index)
	_wallet_panel = PanelContainer.new()
	_wallet_panel.name = "Wallet"
	# Tap the wallet for the Money help page (how to earn pesos, what they buy).
	_wallet_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_wallet_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_sfx("menu_click")
			InstructionsPanel.open_topic(get_tree(), "money"))
	_wallet_panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_right_style())
	_wallet_label = Label.new()
	_wallet_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	_wallet_panel.add_child(_wallet_label)
	row.add_child(_wallet_panel)
	row.add_child(clock_panel)
	TutorialManager.register_target("hud_wallet", _wallet_panel)

func _wallet_shown() -> bool:
	return GameState.pesos > 0 or GameState.get_flag(WALLET_FLAG)

func _refresh_wallet() -> void:
	if _wallet_label != null:
		_wallet_label.text = "₱%d" % GameState.pesos

## RewardManager's popup queue: HUD is its display. Pesos show as a "+₱N"
## toast; the other reward kinds have no display yet and are just drained.
func _on_reward_popup(kind: String, value) -> void:
	if kind == "pesos":
		push_toast(str(value.get("reason", "Pesos")), "+₱%d" % int(value.get("amount", 0)))
	RewardManager.advance_popup()

# --- Fast-forward (v0.1.19 playtest: long walks with Rose were tedious) -------

var _fast_button: Button

## "Fast »" toggle, bottom right, while a cutscene walks the player around.
func _build_fast_forward() -> void:
	_fast_button = Button.new()
	_fast_button.name = "FastForwardButton"
	_fast_button.toggle_mode = true
	_fast_button.focus_mode = Control.FOCUS_NONE
	_fast_button.custom_minimum_size = Vector2(72, 26)
	_fast_button.anchor_left = 1.0
	_fast_button.anchor_top = 1.0
	_fast_button.anchor_right = 1.0
	_fast_button.anchor_bottom = 1.0
	_fast_button.offset_left = -96.0
	_fast_button.offset_top = -62.0
	_fast_button.offset_right = -24.0
	_fast_button.offset_bottom = -36.0
	_fast_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fast_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	UIThemeApplier.apply_button_theme(_fast_button, "secondary")
	_fast_button.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	_fast_button.visible = false
	_fast_button.toggled.connect(func(on: bool):
		AudioManager.play_sfx("menu_click")
		CutsceneManager.set_fast_forward(on))
	add_child(_fast_button)

## Shown during a cutscene, hidden while a dialogue line is up (lines read at
## normal speed anyway) and behind full-screen panels or the Book.
func _update_fast_forward(fullscreen: bool) -> void:
	var show: bool = CutsceneManager.is_playing() and not DialogueUI.is_active() \
			and not fullscreen and not BookUI.visible and not ChapterCard.visible
	_fast_button.visible = show
	if _fast_button.button_pressed != CutsceneManager.fast_forward:
		_fast_button.set_pressed_no_signal(CutsceneManager.fast_forward)
	_fast_button.text = "Fast »»" if CutsceneManager.fast_forward else "Fast »"
