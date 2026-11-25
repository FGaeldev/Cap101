# time_card_action.gd -- a "some time later" card over the black screen between
# two scenes (v1.1.9: the flight from the US to Kalibo read as no time passing).
# Run it while the screen is faded out; the text fades in over the fade, holds,
# and fades away again. An optional sound plays with it (AudioManager id).
#
# JSON usage:
#   {"type": "time_card", "text": "20 hours later", "subtitle": "Kalibo, Aklan",
#    "sfx": "plane_flyby", "seconds": 3.5}
class_name TimeCardCutsceneAction
extends RefCounted

## Above ScreenFade (100), so the card shows on the black.
const LAYER: int = 102
const FADE: float = 0.6

func action_type() -> String:
	return "time_card"

func execute(step: Dictionary, mgr: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	mgr.get_tree().root.add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	layer.add_child(box)
	_add_label(box, str(step.get("text", "")), UIThemeApplier.FONT_SIZE_XXL)
	var subtitle: String = str(step.get("subtitle", ""))
	if not subtitle.is_empty():
		_add_label(box, subtitle, UIThemeApplier.FONT_SIZE_S)
	var sfx: String = str(step.get("sfx", ""))
	if not sfx.is_empty():
		AudioManager.play_sfx(sfx)
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, FADE)
	tween.tween_interval(maxf(float(step.get("seconds", 3.0)) - FADE * 2.0, 0.0))
	tween.tween_property(box, "modulate:a", 0.0, FADE)
	await tween.finished
	layer.queue_free()

func _add_label(box: Control, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
