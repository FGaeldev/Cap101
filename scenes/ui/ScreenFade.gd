# scenes/ui/ScreenFade.gd — attach to CanvasLayer, layer=100 (always on top)
extends CanvasLayer

@onready var rect: ColorRect = $ColorRect  # full-rect anchors, black, modulate.a controls fade

func _ready() -> void:
	FadeManager.register_fade(self)

func fade_in(duration: float = 0.6) -> void:
	rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, duration)
	await tw.finished

func fade_out(duration: float = 0.6) -> void:
	rect.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, duration)
	await tw.finished
