# movement_tutorial.gd — one-shot "how to move" prompt for Chapter 1 intro.
# Dismisses on first detected player movement, persists via GameState.flags
# so it never reshows after seen once (additive save field, TDD §7 safe).
extends CanvasLayer

@onready var panel: PanelContainer = $Control/Panel
@onready var label: Label = $Control/Panel/MarginContainer/Label

const FLAG_KEY := "tutorial_move_seen"
const FADE_TIME := 0.3

var _player: CharacterBody2D = null

func _ready() -> void:
	if GameState.flags.get(FLAG_KEY, false):
		queue_free()
		return

	label.text = "Move toward Lola Jonabel"
	label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)

	var sb := StyleBoxTexture.new()
	sb.texture = UIThemeApplier.DIALOGUE_BOX
	sb.set_texture_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)

	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, FADE_TIME)

	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if _player.velocity.length() > 0.0:
		_dismiss()

func _dismiss() -> void:
	GameState.flags[FLAG_KEY] = true
	set_process(false)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tw.finished.connect(queue_free)
