# HUD.gd
extends CanvasLayer

@onready var quest_label: Label = $VBoxContainer/QuestBG/QuestLabel
@onready var quest_bg: PanelContainer = $VBoxContainer/QuestBG
@onready var dict_btn:   Button = $VBoxContainer/NotesBtn
@onready var dictionary_panel: Control = $DictionaryPanel  # direct child path

func _ready() -> void:
	dict_btn.pressed.connect(_open_dictionary)
	QuestManager.quest_completed.connect(_on_quest_completed)
	_refresh_quest_label()
	_apply_style()

func _apply_style() -> void:
	var bg = StyleBoxFlat.new()
	bg.bg_color     = Color(0.1, 0.1, 0.18, 0.88)
	bg.border_color = Color("e8b84b")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	bg.set_content_margin(SIDE_LEFT, 10)
	bg.set_content_margin(SIDE_RIGHT, 10)
	bg.set_content_margin(SIDE_TOP, 4)
	bg.set_content_margin(SIDE_BOTTOM, 4)
	quest_bg.add_theme_stylebox_override("panel", bg)
	quest_label.add_theme_color_override("font_color", Color("e8b84b"))
	quest_label.add_theme_font_size_override("font_size", 11)
	UIThemeApplier.apply_icon_button_theme(dict_btn, "dictionary")

func _style_btn(btn: Button) -> void:
	UIThemeApplier.apply_button_theme(btn, "primary")

func _refresh_quest_label() -> void:
	var qid = QuestManager.active_quest
	if qid.is_empty():
		quest_label.text = "Quest: —"
		return
	var q = QuestManager.quests.get(qid, {})
	quest_label.text = "Quest: " + q.get("title", qid)

func _open_dictionary() -> void:
	dictionary_panel.open()

func _on_quest_completed(_qid: String) -> void:
	_refresh_quest_label()
