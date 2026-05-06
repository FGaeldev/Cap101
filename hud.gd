# HUD.gd
extends CanvasLayer

@onready var quest_label: Label = $VBoxContainer/QuestLabel
@onready var notes_btn: Button = $VBoxContainer/NotesBtn

# NotesPanel must be in same scene or accessible
@export var notes_panel: NodePath = ""
var _notes_panel_ref: Control = null

func _ready() -> void:
	if notes_panel:
		_notes_panel_ref = get_node(notes_panel)

	notes_btn.pressed.connect(_open_notes)
	QuestManager.quest_completed.connect(_on_quest_completed)
	_refresh_quest_label()

func _refresh_quest_label() -> void:
	var qid = QuestManager.active_quest
	if qid.is_empty():
		quest_label.text = "Quest: —"
		return
	var q = QuestManager.quests.get(qid, {})
	quest_label.text = "Quest: " + q.get("title", qid)

func _open_notes() -> void:
	if _notes_panel_ref:
		_notes_panel_ref.open()

func _on_quest_completed(_qid: String) -> void:
	_refresh_quest_label()
