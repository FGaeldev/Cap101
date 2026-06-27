# puzzle_panel.gd — single-use fill-in-blank puzzle
extends CanvasLayer

@onready var panel:          PanelContainer = $Panel
@onready var sentence_box:   PanelContainer = $Panel/VBox/SentenceBox
@onready var sentence_label: Label          = $Panel/VBox/SentenceBox/SentenceLabel
@onready var choices_box:    HBoxContainer  = $Panel/VBox/ChoicesBox
@onready var feedback_label: Label          = $Panel/VBox/FeedbackLabel
@onready var hint_label:     Label          = $Panel/VBox/HintLabel

var _choice_btns: Array   = []
var _correct_id: String   = ""
var _on_solve_callback    = null
var _showing_feedback: bool = false
var _feedback_timer: float  = 0.0
const FEEDBACK_DURATION     = 1.2

func _ready() -> void:
	add_to_group("puzzle_panel")
	visible = false
	for btn in choices_box.get_children():
		_choice_btns.append(btn)
	_apply_style()

func open_single(
	template: String,
	answer_id: String,
	distractor_ids: Array,
	on_solve: Callable
) -> void:
	_correct_id       = answer_id
	_on_solve_callback = on_solve
	_showing_feedback  = false
	feedback_label.text = ""

	# Build sentence
	sentence_label.text = template.replace("___", "[ _______ ]")

	# Shuffle choices
	var choices = ([answer_id] + distractor_ids)
	choices.shuffle()

	for i in range(_choice_btns.size()):
		var btn: Button = _choice_btns[i]
		if i < choices.size():
			var word_data = WordBank.get_word(choices[i])
			btn.text     = word_data.get("akeanon", "???")
			btn.visible  = true
			btn.disabled = false
			_reset_btn(btn)
			if btn.pressed.is_connected(_on_choice):
				btn.pressed.disconnect(_on_choice)
			btn.pressed.connect(_on_choice.bind(choices[i], btn))
		else:
			btn.visible = false

	visible = true

func _on_choice(word_id: String, btn: Button) -> void:
	if _showing_feedback: return

	if word_id == _correct_id:
		feedback_label.text = "Husto! Maayo gid!"
		feedback_label.add_theme_color_override("font_color", Color("2d9a5a"))
		_flash_btn(btn, Color("2d9a5a"))
		for b in _choice_btns:
			b.disabled = true
		_showing_feedback = true
		_feedback_timer   = 0.0
	else:
		feedback_label.text = "Mali, sulayi liwat!"
		feedback_label.add_theme_color_override("font_color", Color("8b2e2e"))
		_flash_btn(btn, Color("8b2e2e"))
		# Wrong — re-enable after brief flash
		await get_tree().create_timer(0.4).timeout
		for b in _choice_btns:
			b.disabled = false
			_reset_btn(b)
		feedback_label.text = ""

func _process(delta: float) -> void:
	if not _showing_feedback: return
	_feedback_timer += delta
	if _feedback_timer >= FEEDBACK_DURATION:
		_showing_feedback = false
		visible = false
		if _on_solve_callback:
			_on_solve_callback.call()

func _flash_btn(btn: Button, color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = color.darkened(0.3)
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal",   s)
	btn.add_theme_stylebox_override("disabled", s)
	btn.add_theme_color_override("font_color_disabled", Color("fdf6e3"))

func _reset_btn(btn: Button) -> void:
	var path = "res://assets/ui/button_normal.tres"
	if ResourceLoader.exists(path):
		btn.add_theme_stylebox_override("normal",  load(path))
		btn.add_theme_stylebox_override("hover",   load("res://assets/ui/button_hover.tres"))
		btn.add_theme_stylebox_override("disabled",load(path))
	else:
		var s = StyleBoxFlat.new()
		s.bg_color     = Color("1a6b3a")
		s.border_color = Color("1a4a2e")
		s.set_border_width_all(3)
		s.set_corner_radius_all(3)
		s.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_color_override("font_color",         Color("f0faf0"))
	btn.add_theme_color_override("font_hover_color",   Color("1a2e0a"))
	btn.add_theme_color_override("font_pressed_color", Color("f0faf0"))

func _apply_style() -> void:
	panel.custom_minimum_size = Vector2(340, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)

	var path = "res://assets/ui/panel.tres"
	if ResourceLoader.exists(path):
		panel.add_theme_stylebox_override("panel", load(path))
	else:
		var ps = StyleBoxFlat.new()
		ps.bg_color     = Color("f0faf0")
		ps.border_color = Color("1a4a2e")
		ps.set_border_width_all(4)
		ps.set_corner_radius_all(6)
		ps.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", ps)

	hint_label.add_theme_color_override("font_color", Color("1a4a2e"))
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var ss = StyleBoxFlat.new()
	ss.bg_color     = Color("eafaf0")
	ss.border_color = Color("4aad6a")
	ss.set_border_width_all(2)
	ss.set_corner_radius_all(4)
	ss.set_content_margin_all(12)
	sentence_box.add_theme_stylebox_override("panel", ss)
	sentence_label.add_theme_color_override("font_color", Color("0d2e1a"))
	sentence_label.add_theme_font_size_override("font_size", 13)
	sentence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sentence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	choices_box.alignment = BoxContainer.ALIGNMENT_CENTER
	for btn in _choice_btns:
		btn.custom_minimum_size = Vector2(96, 34)
		btn.add_theme_font_size_override("font_size", 12)

	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
