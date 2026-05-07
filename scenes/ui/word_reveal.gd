extends PanelContainer

@onready var word_label: Label = $VBoxContainer/WordLabel
@onready var new_label:  Label = $VBoxContainer/NewWordLabel

var _timer: float = 0.0
const SHOW_DURATION = 2.0

func _ready() -> void:
	visible = false
	_apply_style()

func show_word(word: String) -> void:
	word_label.text = word
	visible = true
	_timer  = 0.0

func _process(delta: float) -> void:
	if not visible: return
	_timer += delta
	var alpha = 1.0 - clamp((_timer - 1.2) / 0.8, 0.0, 1.0)
	modulate.a = alpha
	if _timer >= SHOW_DURATION:
		visible = false
		modulate.a = 1.0

func _apply_style() -> void:
	new_label.add_theme_color_override("font_color", Color("e8b84b"))
	new_label.add_theme_font_size_override("font_size", 10)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.text = "Bag-ong Pulong!"

	word_label.add_theme_color_override("font_color", Color("fdf6e3"))
	word_label.add_theme_font_size_override("font_size", 18)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
