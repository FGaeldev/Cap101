# HUD.gd
extends CanvasLayer

@onready var quest_label: Label = $VBoxContainer/QuestBG/QuestLabel
@onready var quest_bg: PanelContainer = $VBoxContainer/QuestBG
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
	QuestManager.quest_completed.connect(_on_quest_completed)
	_refresh_quest_label()
	_apply_style()
	UIThemeApplier.apply_icon_button_theme(menu_button, "menu")
	menu_button.pressed.connect(_on_menu_button_pressed)

func _on_menu_button_pressed() -> void:
	# Mobile has no keyboard ui_cancel — this is the only way to reach
	# BookUI on a touch-only device (Android back button still works too,
	# via BackButtonBridge). Defaults to "settings" tab, same as ui_cancel.
	# No AudioManager.play_sfx() here — BookUI.open()/switch_tab() already
	# plays "menu_click" itself.
	BookUI.open()

func _apply_style() -> void:
	# Was flat navy box w/ hardcoded gold border — off the book/parchment
	# system entirely. Now matches BookUI chrome via UIThemeApplier.
	quest_bg.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	quest_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	quest_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)

func _style_btn(btn: Button) -> void:
	UIThemeApplier.apply_button_theme(btn, "primary")

func _refresh_quest_label() -> void:
	var qid = QuestManager.active_quest
	if qid.is_empty():
		quest_label.text = "Quest: —"
		return
	var q = QuestManager.quests.get(qid, {})
	quest_label.text =q.get("title", qid)

func _on_quest_completed(_qid: String) -> void:
	_refresh_quest_label()
