# main_menu.gd — Stardew-style tropical main menu
extends Control

@onready var title_label:   Label  = $BookPanel/Spread/LeftSide/CenterContainer/VBoxContainer/TitleLabel
@onready var sub_label:     Label  = $BookPanel/Spread/LeftSide/CenterContainer/VBoxContainer/SubLabel
@onready var start_btn:    Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/StartBtn
@onready var continue_btn: Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/ContinueBtn
@onready var instructions_btn: Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/InstructionsBtn
@onready var settings_btn: Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/SettingsBtn
@onready var quit_btn:     Button = $BookPanel/Spread/RightPage/CenterContainer/Buttons/QuitBtn

const MAIN = "res://scenes/Game.tscn"
## New-game name prompt; hands off to MAIN once a name is confirmed.
const NAME_ENTRY = "res://scenes/ui/name_entry.tscn"
const InstructionsPanel := preload("res://scripts/ui/instructions_panel.gd")

func _ready() -> void:
	_apply_bg()
	_apply_style()
	_check_save()
	_add_version_label()
	# Android closed the game while it was in the background (GameState resume
	# note): go straight back into that save, paused, instead of the title screen.
	var resume_slot: int = GameState.take_resume()
	if resume_slot > 0:
		GameState.resume_into_pause = true
		_load_slot.call_deferred(resume_slot)
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	instructions_btn.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		InstructionsPanel.open(get_tree())
	)
	settings_btn.pressed.connect(_on_settings)
	_add_credits_button()
	quit_btn.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		get_tree().quit()
	)

## Build version in the bottom-right corner, so testers can say which build a
## bug came from. Set in project.godot (application/config/version); see RELEASING.md.
func _add_version_label() -> void:
	var v: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if v == "":
		return
	var lbl := Label.new()
	lbl.text = "v" + v
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(1, 1, 1, 0.6)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(lbl)

func _check_save() -> void:
	continue_btn.disabled = not GameState.has_any_save()

func _on_start() -> void:
	AudioManager.play_sfx("menu_click")
	# First game ever: straight into slot 1. Otherwise let the player pick a slot.
	if not GameState.has_any_save():
		_start_new_in(1)
		return
	_open_slots("new")

## Always asks which game, even with one save, so it's clear which slot loads.
func _on_continue() -> void:
	AudioManager.play_sfx("menu_click")
	_open_slots("load")

func _start_new_in(slot: int) -> void:
	GameState.use_slot(slot)
	GameState.player_name = ""  # force fresh name entry; the slot's old save stays until a name is confirmed
	get_tree().change_scene_to_file(NAME_ENTRY)

func _load_slot(slot: int) -> void:
	GameState.use_slot(slot)
	if not GameState.load_game():
		_close_slots()
		continue_btn.text = "Save unreadable"
		continue_btn.disabled = true
		return
	get_tree().change_scene_to_file(MAIN)

# --- save slot picker ------------------------------------------------------------
# One overlay for both buttons: "new" (any slot; a used one asks before it's
# replaced) and "load" (only slots with a game). Each used slot can be deleted.

var _slots_overlay: Control = null
var _slots_box: VBoxContainer = null
var _slots_mode: String = ""

func _open_slots(mode: String) -> void:
	_slots_mode = mode
	if _slots_overlay == null:
		_slots_overlay = Control.new()
		_slots_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_slots_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_slots_overlay.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		_slots_overlay.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(18))
		panel.custom_minimum_size = Vector2(420, 0)
		center.add_child(panel)
		_slots_box = VBoxContainer.new()
		_slots_box.add_theme_constant_override("separation", 8)
		panel.add_child(_slots_box)
		add_child(_slots_overlay)
	_slots_overlay.visible = true
	_show_slot_list()

func _close_slots() -> void:
	if _slots_overlay:
		_slots_overlay.visible = false

func _clear_slot_box() -> void:
	for c in _slots_box.get_children():
		_slots_box.remove_child(c)
		c.queue_free()

func _slot_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _slot_button(text: String, variant: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_btn(b, variant)
	b.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		on_press.call())
	return b

func _show_slot_list() -> void:
	_clear_slot_box()
	var title := "Start a new game in which slot?" if _slots_mode == "new" else "Continue which game?"
	_slots_box.add_child(_slot_label(title, UIThemeApplier.FONT_SIZE_L, UIThemeApplier.TEXT_EMPHASIS))
	var focus: Button = null
	for s in range(1, GameState.SLOT_COUNT + 1):
		var info: Dictionary = GameState.slot_summary(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var text := "Slot %d   ·   Empty" % s
		if info.get("exists", false):
			var who: String = info["name"] if not str(info["name"]).is_empty() else "No name"
			text = "Slot %d   ·   %s\nChapter %d   ·   %s" % [s, who, int(info["chapter"]), _saved_text(int(info["saved"]))]
			# Which build last saved it; older builds didn't record one.
			var ver: String = str(info.get("version", ""))
			text += "   ·   v%s" % ver if not ver.is_empty() else "   ·   older version"
		var pick := _slot_button(text, "secondary", _on_slot_picked.bind(s, bool(info.get("exists", false))))
		pick.custom_minimum_size = Vector2(0, 56)
		pick.disabled = _slots_mode == "load" and not info.get("exists", false)
		row.add_child(pick)
		if info.get("exists", false):
			var del := _slot_button("Delete", "danger", _ask_delete.bind(s))
			del.size_flags_horizontal = Control.SIZE_SHRINK_END
			row.add_child(del)
		_slots_box.add_child(row)
		if focus == null and not pick.disabled and (s == GameState.save_slot or _slots_mode == "new"):
			focus = pick
	_slots_box.add_child(_slot_button("Back", "secondary", _close_slots))
	if focus:
		focus.grab_focus()

func _ask_delete(slot: int) -> void:
	_confirm("Delete slot %d? This can't be undone." % slot, "Delete", _delete_slot.bind(slot))

func _delete_slot(slot: int) -> void:
	GameState.delete_slot(slot)
	_check_save()
	if _slots_mode == "load" and not GameState.has_any_save():
		_close_slots()
	else:
		_show_slot_list()

func _on_slot_picked(slot: int, used: bool) -> void:
	if _slots_mode == "load":
		_load_slot(slot)
	elif used:
		var who: String = str(GameState.slot_summary(slot).get("name", ""))
		_confirm("Start a new game in slot %d? %s's game there will be replaced." % [slot, who if not who.is_empty() else "The"],
				"Start new", func(): _start_new_in(slot))
	else:
		_start_new_in(slot)

func _confirm(question: String, yes_text: String, on_yes: Callable) -> void:
	_clear_slot_box()
	_slots_box.add_child(_slot_label(question, UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_DEFAULT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_slot_button(yes_text, "danger", on_yes))
	var no := _slot_button("Cancel", "secondary", _show_slot_list)
	row.add_child(no)
	_slots_box.add_child(row)
	no.grab_focus()

## "Nov 18, 11:01 PM" in the device's time zone.
func _saved_text(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var h: int = int(d["hour"])
	return "%s %d, %d:%02d %s" % [months[int(d["month"]) - 1], int(d["day"]), 12 if h % 12 == 0 else h % 12, int(d["minute"]), "AM" if h < 12 else "PM"]

# --- credits / about -------------------------------------------------------------
# Text lives in data/credits.json so the team can edit it without touching code.

const CREDITS_PATH := "res://data/credits.json"
var _credits_overlay: Control = null

## "Help" (the instructions) and "About" (the credits) share one row where
## Instructions was, so the menu reads Start / Continue / Help · About /
## Settings / Exit instead of six full-width buttons.
func _add_credits_button() -> void:
	var btn := Button.new()
	btn.name = "CreditsBtn"
	btn.text = "About"
	_style_btn(btn, "secondary")
	instructions_btn.text = "Help"
	var column: Node = instructions_btn.get_parent()
	var row := HBoxContainer.new()
	row.name = "HelpAboutRow"
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	column.move_child(row, instructions_btn.get_index())
	instructions_btn.reparent(row)
	row.add_child(btn)
	for b: Button in [instructions_btn, btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func():
		AudioManager.play_sfx("menu_click")
		_open_credits())

func _open_credits() -> void:
	if _credits_overlay != null:
		_credits_overlay.visible = true
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	if not data is Dictionary:
		push_error("MainMenu: %s is missing or malformed" % CREDITS_PATH)
		return
	_credits_overlay = Control.new()
	_credits_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style(18))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	outer.add_child(_slot_label(str(title_label.text), UIThemeApplier.FONT_SIZE_L, UIThemeApplier.TEXT_EMPHASIS))
	outer.add_child(_slot_label("v" + GameState.game_version(), UIThemeApplier.FONT_SIZE_XS, UIThemeApplier.TEXT_DISABLED))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, get_viewport_rect().size.y * 0.55)
	outer.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)
	body.add_child(_slot_label(str(data.get("about", "")), UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT))
	for section: Dictionary in data.get("sections", []):
		var heading := _slot_label(str(section.get("title", "")), UIThemeApplier.FONT_SIZE_M, UIThemeApplier.TEXT_EMPHASIS)
		heading.custom_minimum_size = Vector2(0, 32)
		heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		body.add_child(heading)
		for line in section.get("lines", []):
			body.add_child(_slot_label(str(line), UIThemeApplier.FONT_SIZE_S, UIThemeApplier.TEXT_DEFAULT))
	var back := _slot_button("Back", "secondary", _close_credits)
	outer.add_child(back)
	add_child(_credits_overlay)
	back.grab_focus()

func _close_credits() -> void:
	if _credits_overlay:
		_credits_overlay.visible = false

func _on_settings() -> void:
	AudioManager.play_sfx("menu_click")
	BookUI.open("settings")
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _credits_overlay and _credits_overlay.visible:
			_close_credits()
			get_viewport().set_input_as_handled()
			return
		if _slots_overlay and _slots_overlay.visible:
			_close_slots()
			get_viewport().set_input_as_handled()
			return
		get_tree().quit()

func _apply_bg() -> void:
	# Dark forest night bg — deep green-black gradient feel via ColorRect
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0a1a0e")
	add_child(bg)
	move_child(bg, 0)

	# Subtle vignette overlay
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
	add_child(vignette)
	move_child(vignette, 1)

func _apply_style() -> void:
	# Title — book-cover gold (UI_STYLE_GUIDE §2)
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	title_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_HERO)
	UIThemeApplier.apply_display_font(title_label)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle — secondary/meta text role (UI_STYLE_GUIDE §2)
	sub_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DISABLED)
	sub_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Buttons
	_style_btn(start_btn, "secondary")
	_style_btn(continue_btn, "secondary")
	_style_btn(instructions_btn, "secondary")
	_style_btn(settings_btn, "secondary")
	_style_btn(quit_btn, "danger")

func _style_btn(btn: Button, variant: String) -> void:
	UIThemeApplier.apply_button_theme(btn, variant)
