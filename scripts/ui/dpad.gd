# dpad.gd -- on-screen 4-way D-pad, the alternative to the HUD's VirtualJoystick
# (Settings > Movement controls, Accessibility.movement_controls).
#
# Like the joystick it only presses the ui_up/down/left/right actions, so
# player.gd's get_input_dir() and the walk state need nothing new. Touch
# anywhere on the pad and the arm under the finger is held; slide to another arm
# without lifting. Multi-touch safe: it follows only the finger that started on
# it. Mouse works too (desktop testing).
#
# Look: assets/ui/Dpad.png, four arrow keys on a 3x3 grid of 32 px cells. Each
# key is drawn from its cell; the held one sinks a pixel and darkens.
class_name DPad
extends Control

const ACTIONS := {
	Vector2i.UP: &"ui_up", Vector2i.DOWN: &"ui_down",
	Vector2i.LEFT: &"ui_left", Vector2i.RIGHT: &"ui_right",
}
## Fraction of the pad's half-size around the centre that counts as no direction.
const DEAD_ZONE: float = 0.18
const ART := preload("res://assets/ui/Dpad.png")
## Each key's cell in the art (3x3 grid of 32 px cells, centre empty).
const CELLS := {
	Vector2i.UP: Rect2(32, 0, 32, 32), Vector2i.DOWN: Rect2(32, 64, 32, 32),
	Vector2i.LEFT: Rect2(0, 32, 32, 32), Vector2i.RIGHT: Rect2(64, 32, 32, 32),
}
const HELD_TINT := Color(0.82, 0.78, 0.74)

var _dir: Vector2i = Vector2i.ZERO
var _finger: int = -1        # touch index that owns the pad, -1 = none
var _mouse_down: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	# No walking through a conversation: drop any held direction and ignore taps.
	if DialogueUI.is_active():
		_release()
		accept_event()
		return
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
	var scale_xy := size / Vector2(ART.get_size())
	for d: Vector2i in CELLS:
		var src: Rect2 = CELLS[d]
		var dst := Rect2(src.position * scale_xy, src.size * scale_xy)
		if d == _dir:
			draw_texture_rect_region(ART, Rect2(dst.position + Vector2(0, 1), dst.size), src, HELD_TINT)
		else:
			draw_texture_rect_region(ART, dst, src)
