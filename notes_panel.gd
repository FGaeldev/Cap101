# NotesPanel.gd
extends PanelContainer

@onready var notes_list: VBoxContainer = $VBoxContainer/ScrollContainer/NotesList
@onready var close_btn: Button = $VBoxContainer/HBoxContainer/CloseBtn

func _ready() -> void:
	close_btn.pressed.connect(func(): visible = false)
	visible = false

func open() -> void:
	_rebuild()
	visible = true

func _rebuild() -> void:
	# Clear old entries
	for child in notes_list.get_children():
		child.queue_free()

	# One entry per exposed word
	for word_id in GameState.word_exposures:
		var word_data = WordBank.get_word(word_id)
		if word_data.is_empty():
			continue
		_add_entry(word_id, word_data)

func _add_entry(word_id: String, word_data: Dictionary) -> void:
	var container = VBoxContainer.new()

	# Akeanon word (read-only)
	var akeanon_label = Label.new()
	akeanon_label.text = word_data.get("akeanon", "???")
	akeanon_label.add_theme_font_size_override("font_size", 18)
	container.add_child(akeanon_label)

	# Player's meaning (editable)
	var meaning_input = LineEdit.new()
	meaning_input.placeholder_text = "Isulat ang buot silingon..."
	meaning_input.text = GameState.get_note(word_id)
	meaning_input.text_submitted.connect(
		func(new_text: String): GameState.save_note(word_id, new_text)
	)
	# Also save on focus lost
	meaning_input.focus_exited.connect(
		func(): GameState.save_note(word_id, meaning_input.text)
	)
	container.add_child(meaning_input)

	# Exposure count (subtle)
	var exposure_label = Label.new()
	exposure_label.text = "Encounters: %d" % GameState.get_exposure(word_id)
	exposure_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(exposure_label)

	# Separator
	container.add_child(HSeparator.new())

	notes_list.add_child(container)
