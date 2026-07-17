# scenes/ui/WordRevealToast.gd
# Minimal top-right vocab toast. Queues bursts (multi-word_ids lines) so
# entries never overlap/cut each other off. One instance, lives in the
# persistent root scene — connects to GameState directly, no per-scene wiring.
extends CanvasLayer

@onready var toast: PanelContainer = $Control/Toast
@onready var akeanon_label: Label = $Control/Toast/MarginContainer/VBoxContainer/AkeanonLabel
@onready var gloss_label: Label = $Control/Toast/MarginContainer/VBoxContainer/GlossLabel

const DISPLAY_TIME := 2.0
const FADE_TIME := 0.25

var _queue: Array = []   # Array[Dictionary] {akeanon, gloss}
var _busy := false

func _ready() -> void:
	GameState.word_learned.connect(_on_word_learned)
	toast.modulate.a = 0.0
	akeanon_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
	gloss_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	gloss_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	gloss_label.clip_text = true
	gloss_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sb := StyleBoxTexture.new()
	sb.texture = UIThemeApplier.DIALOGUE_BOX
	sb.set_texture_margin_all(6)
	toast.add_theme_stylebox_override("panel", sb)

func _on_word_learned(_id: String, akeanon: String, gloss: String) -> void:
	_queue.append({"akeanon": akeanon, "gloss": gloss})
	if not _busy:
		_process_queue()

func _process_queue() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var entry: Dictionary = _queue.pop_front()
	akeanon_label.text = entry["akeanon"]
	gloss_label.text = entry["gloss"]

	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, FADE_TIME)
	tw.tween_interval(DISPLAY_TIME)
	tw.tween_property(toast, "modulate:a", 0.0, FADE_TIME)
	tw.finished.connect(_process_queue)
