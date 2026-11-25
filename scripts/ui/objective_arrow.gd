# objective_arrow.gd -- points at the "go there yourself" goal (objective.gd).
# On screen: a bobbing arrow above the target with the goal's label. Off
# screen: an arrow at the screen edge turned toward it. Hidden during cutscenes
# and dialogue, and when the goal is in another level. Game.gd adds it to the
# UI layer; reaching a non-door target (REACH_PX) completes the goal.
extends Control

const Objective := preload("res://scripts/util/objective.gd")
const COLOR := UIThemeApplier.COLOR_POINTER
const OUTLINE := Color(0.22, 0.16, 0.06)
const SIZE: float = 14.0
const EDGE_MARGIN: float = 36.0
const BOB: float = 4.0
## World px above the target the on-screen arrow floats.
const LIFT: float = 22.0

var _t: float = 0.0
## Screen position and direction of the arrow this frame; visible flag.
var _pos := Vector2.ZERO
var _dir := Vector2.DOWN
var _on_screen := false
var _show := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	# Anchors don't size a Control under a CanvasLayer here: cover the
	# viewport (in this layer's units) ourselves.
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	size = to_local.basis_xform(get_viewport_rect().size)
	var was: bool = _show
	_show = _update()
	if _show or was:
		queue_redraw()

## Works out where to draw; false when nothing should show.
func _update() -> bool:
	if not Objective.active() or CutsceneManager.is_playing() or DialogueUI.is_active() or MapManager.is_transitioning:
		return false
	if not CutsceneManager.has_actor("player"):
		return false
	var player: Node2D = CutsceneManager.get_actor("player")
	var level: Node = player.get_parent()
	var target: Node2D = Objective.target_node(level)
	if target == null:
		return false
	if Objective.check_reached(player, target):
		return false
	# World -> viewport (the camera), then viewport -> this control (the UI
	# layer may be scaled by the UI size setting).
	var world_to_screen: Transform2D = get_viewport().get_canvas_transform()
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	# Point at where the player has to stand (a seat's approach tile), not the node.
	var spot: Vector2 = target.global_position if target.has_method("uses_button") else Objective.reach_point(target)
	var at_target: Vector2 = to_local * (world_to_screen * spot)
	var screen: Vector2 = to_local * (world_to_screen * (spot + Vector2(0, -LIFT)))
	var rect := Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)
	# On screen = the target itself is in view; the arrow floats above it, kept
	# inside the screen (a door on the top edge still gets its arrow).
	_on_screen = Rect2(Vector2.ZERO, size).grow(-8.0).has_point(at_target)
	if _on_screen:
		_pos = Vector2(screen.x, maxf(screen.y, SIZE * 2.0 + 4.0)) + Vector2(0, sin(_t * 4.0) * BOB)
		_dir = Vector2.DOWN
	else:
		var center: Vector2 = rect.get_center()
		_dir = (screen - center).normalized()
		_pos = Vector2(clampf(screen.x, rect.position.x, rect.end.x), clampf(screen.y, rect.position.y, rect.end.y))
		_pos -= _dir * sin(_t * 4.0) * BOB
	return true

func _draw() -> void:
	if not _show:
		return
	var side: Vector2 = _dir.orthogonal()
	var tip: Vector2 = _pos
	# Long and narrow, so the way it points reads at a glance.
	var back: Vector2 = tip - _dir * SIZE * 2.0
	var points := PackedVector2Array([tip, back + side * SIZE * 0.45, back - side * SIZE * 0.45])
	draw_colored_polygon(points, COLOR)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), OUTLINE, 2.0)
	if _on_screen:
		var font: Font = get_theme_default_font()
		var text: String = Objective.label()
		var size: int = UIThemeApplier.FONT_SIZE_S
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := back + Vector2(-w / 2.0, -10.0)
		if at.y < float(size):  # no room above (target on the top edge): label under the tip
			at = tip + Vector2(-w / 2.0, float(size) + 10.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, OUTLINE)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR)
