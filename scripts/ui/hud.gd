# HUD.gd
extends CanvasLayer

const QUEST_BANNER_SCENE: PackedScene = preload("res://scenes/ui/quest_banner.tscn")

@onready var vbox: VBoxContainer = $VBoxContainer
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
	QuestManager.quest_started.connect(_on_quest_list_changed)
	QuestManager.quest_completed.connect(_on_quest_list_changed)
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

## Rebuilds the VBoxContainer's quest rows from QuestManager.active_quests.
## Instances quest_banner.tscn once per active quest. Movement tutorial and
## similar one-shot prompts are now regular quest entries (completion_trigger
## field, see QuestManager) — no separate message-row system needed.
func _rebuild_quest_rows() -> void:
	for child in vbox.get_children():
		child.queue_free()

	if QuestManager.active_quests.is_empty():
		_add_quest_row("", "Quest: —")
		return

	for qid in QuestManager.active_quests:
		var q = QuestManager.quests.get(qid, {})
		_add_quest_row(qid, q.get("title", qid))

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
