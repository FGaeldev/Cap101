# dpad.gd -- on-screen 4-way D-pad, the alternative to the HUD's VirtualJoystick
# (Settings > Movement controls, Accessibility.movement_controls).
#
# Like the joystick it only presses the ui_up/down/left/right actions, so
# player.gd's get_input_dir() and the walk state need nothing new. Touch
# anywhere on the pad and the arm under the finger is held; slide to another arm
# without lifting. Multi-touch safe: it follows only the finger that started on
# it. Mouse works too (desktop testing).
#
# Placeholder look drawn in _draw(): a cross in the UI palette with arrows, the
# held arm highlighted. To use art later, draw textures here (or swap _draw for
# four TextureRects) and keep the input code.
class_name DPad
extends Control

const ACTIONS := {
	Vector2i.UP: &"ui_up", Vector2i.DOWN: &"ui_down",
	Vector2i.LEFT: &"ui_left", Vector2i.RIGHT: &"ui_right",
}
## Fraction of the pad's half-size around the centre that counts as no direction.
const DEAD_ZONE: float = 0.18
## Arm width as a fraction of the pad's size.
const ARM: float = 0.36
const FILL := Color("e6c79c")
const FILL_HELD := Color("f2c14e")
const EDGE := Color("4c2020")
const ARROW := Color("4c2020")

var _dir: Vector2i = Vector2i.ZERO
var _finger: int = -1        # touch index that owns the pad, -1 = none
var _mouse_down: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func():
		if not visible:
			_release())

func _exit_tree() -> void:
	_release()

func _notification(what: int) -> void:
	# Losing focus mid-press (alt-tab, phone call) must not leave a direction held.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			_finger = event.index
			_set_dir(_dir_at(event.position))
		elif not event.pressed and event.index == _finger:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _finger:
		_set_dir(_dir_at(event.position))
		accept_event()
	# Real mouse only: mouse events emulated from touch would double-handle.
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed
		if event.pressed:
			_set_dir(_dir_at(event.position))
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_down and event.device != InputEvent.DEVICE_ID_EMULATION:
		_set_dir(_dir_at(event.position))
		accept_event()

## Arm under a point in the pad's local space, or ZERO in the dead zone.
func _dir_at(pos: Vector2) -> Vector2i:
	var half := size / 2.0
	var v := (pos - half) / half
	if v.length() < DEAD_ZONE:
		return Vector2i.ZERO
	if absf(v.x) > absf(v.y):
		return Vector2i.RIGHT if v.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if v.y > 0.0 else Vector2i.UP

func _set_dir(dir: Vector2i) -> void:
	if dir == _dir:
		return
	if _dir != Vector2i.ZERO:
		Input.action_release(ACTIONS[_dir])
	_dir = dir
	if _dir != Vector2i.ZERO:
		Input.action_press(ACTIONS[_dir])
	queue_redraw()

func _release() -> void:
	_finger = -1
	_mouse_down = false
	_set_dir(Vector2i.ZERO)

## Direction currently held (tests / tutorial).
func held() -> Vector2i:
	return _dir

func _draw() -> void:
	var s := size
	var arm := minf(s.x, s.y) * ARM
	var vert := Rect2((s.x - arm) / 2.0, 0.0, arm, s.y)
	var horiz := Rect2(0.0, (s.y - arm) / 2.0, s.x, arm)
	for r in [vert, horiz]:
		draw_rect(r.grow(2.0), EDGE)
	for r in [vert, horiz]:
		draw_rect(r, FILL)
	if _dir != Vector2i.ZERO:
		draw_rect(_arm_rect(_dir, arm), FILL_HELD)
	for d: Vector2i in ACTIONS:
		_draw_arrow(d, arm)

## The outer part of one arm (the bit the highlight covers).
func _arm_rect(d: Vector2i, arm: float) -> Rect2:
	var s := size
	var reach := (minf(s.x, s.y) - arm) / 2.0
	match d:
		Vector2i.UP: return Rect2((s.x - arm) / 2.0, 0.0, arm, reach)
		Vector2i.DOWN: return Rect2((s.x - arm) / 2.0, s.y - reach, arm, reach)
		Vector2i.LEFT: return Rect2(0.0, (s.y - arm) / 2.0, reach, arm)
	return Rect2(s.x - reach, (s.y - arm) / 2.0, reach, arm)

func _draw_arrow(d: Vector2i, arm: float) -> void:
	var r := _arm_rect(d, arm)
	var c := r.get_center()
	var a := arm * 0.22
	var f := Vector2(d) * a        # tip direction
	var side := Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([c + f, c - f * 0.6 + side, c - f * 0.6 - side]), ARROW)
