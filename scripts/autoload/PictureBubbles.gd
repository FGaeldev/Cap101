# PictureBubbles.gd -- speech bubbles with a small drawing in them, above a
# character's head, for objects being shown or named and for feelings (!, ?, zzz).
# See docs/CHAPTER2_PLAN.md step 2 and the storyboard's "Picture bubbles" section.
#
# On a dialogue line (Comp_Dialogue.gd calls show_for_line):
#   "bubble": "star_fruit"                  one icon over the speaker
#   "bubble": ["fish", "chicken", "egg"]    the picture changes each time the
#                                           typewriter reaches the next \ word
#   "bubble_on": "player"                   over someone else (actor id)
# The bubble closes when the next line starts or the dialogue ends.
#
# In a cutscene, for silent beats (bubble_action.gd):
#   {"type": "bubble", "actor": "Lola Jonabel", "icon": "bell", "seconds": 2}
#
# Icons: data/bubble_icons.json names the cells of one sheet, left to right.
extends Node

const ICONS_PATH: String = "res://data/bubble_icons.json"
const PLAYER_SPEAKER: String = "Player"
const PLAYER_ACTOR: String = "player"

## Colours sampled from the dialogue box, same as word_popup.gd's tail.
const FILL := Color("ffd6a8")
const EDGE := Color("7d3f4b")
## Gap between the icon and the bubble's edge, in world pixels.
const PADDING: float = 3.0
const TAIL_HALF_WIDTH: float = 3.0
const TAIL_HEIGHT: float = 4.0
## Fallback for the tail tip relative to the actor's origin when it has no
## AnimatedSprite2D to measure (origin = the tile's bottom-left corner).
const HEAD_OFFSET := Vector2(8, -24)
## Gap between the top of the sprite and the tail's tip.
const HEAD_GAP: float = 1.0

var _sheet: Texture2D = null
var _cell: int = 16
var _cells: Dictionary = {}        # icon name -> cell index
var _line_bubble: Node2D = null    # the bubble owned by the current dialogue line
var _line_icons: Array = []        # its icons, in order of the line's \ words
var _line_shown: int = -1

func _ready() -> void:
	_load_icons()

func _load_icons() -> void:
	if not FileAccess.file_exists(ICONS_PATH):
		push_warning("PictureBubbles: %s is missing; bubbles are off." % ICONS_PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(ICONS_PATH))
	if not data is Dictionary:
		push_error("PictureBubbles: %s does not parse." % ICONS_PATH)
		return
	_cell = int(data.get("cell", 16))
	var names: Array = data.get("icons", [])
	for i in names.size():
		_cells[str(names[i])] = i
	var sheet_path: String = str(data.get("sheet", ""))
	if ResourceLoader.exists(sheet_path):
		_sheet = load(sheet_path)
	else:
		push_warning("PictureBubbles: icon sheet %s is missing." % sheet_path)

func has_icon(icon: String) -> bool:
	return _cells.has(icon)

# --- dialogue lines -------------------------------------------------------------

## Called for every dialogue line as it appears. Lines without "bubble" just
## close the previous line's bubble.
func show_for_line(line: Dictionary) -> void:
	clear_line()
	var spec = line.get("bubble", null)
	if spec == null:
		return
	var icons: Array = spec if spec is Array else [spec]
	if icons.is_empty():
		return
	var actor_id: String = str(line.get("bubble_on", line.get("speaker", "")))
	if actor_id == PLAYER_SPEAKER:
		actor_id = PLAYER_ACTOR
	_line_bubble = _make_bubble(actor_id, str(icons[0]))
	if _line_bubble == null:
		return
	_line_icons = icons
	_line_shown = 0

## The dialogue box reports how far it has typed. With a list of icons, the
## picture follows the line's \ words: the n-th marked word shows the n-th icon.
func on_typed(raw_text: String, shown_chars: int) -> void:
	if _line_bubble == null or _line_icons.size() < 2:
		return
	var reached: int = 0
	var index: int = 0
	while index < _line_icons.size():
		var span: Vector2i = TextUtil.marked_word_span(raw_text, index)
		if span.x == -1 or span.x >= shown_chars:
			break
		reached = index
		index += 1
	if reached != _line_shown:
		_line_shown = reached
		_set_icon(_line_bubble, str(_line_icons[reached]))

func clear_line() -> void:
	if is_instance_valid(_line_bubble):
		_line_bubble.queue_free()
	_line_bubble = null
	_line_icons = []
	_line_shown = -1

# --- cutscenes ------------------------------------------------------------------

## Shows a bubble for a while, then removes it. Awaitable.
func pop(actor_id: String, icon: String, seconds: float) -> void:
	var bubble: Node2D = _make_bubble(actor_id, icon)
	if bubble == null:
		return
	await get_tree().create_timer(maxf(seconds, 0.1)).timeout
	if is_instance_valid(bubble):
		bubble.queue_free()

# --- drawing --------------------------------------------------------------------

func _make_bubble(actor_id: String, icon: String) -> Node2D:
	if _sheet == null:
		return null
	if not _cells.has(icon):
		push_warning("PictureBubbles: unknown icon '%s'." % icon)
		return null
	if not CutsceneManager.has_actor(actor_id):
		return null
	var actor: Node = CutsceneManager.get_actor(actor_id)
	if not actor is Node2D:
		return null
	var bubble := _Bubble.new()
	bubble.cell = _cell
	bubble.texture = _sheet
	bubble.z_as_relative = false
	bubble.z_index = 100
	bubble.position = _head_of(actor)
	actor.add_child(bubble)
	_set_icon(bubble, icon)
	return bubble

## Just above the top of the actor's sprite, centered on it.
func _head_of(actor: Node2D) -> Vector2:
	var sprite := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return HEAD_OFFSET
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return HEAD_OFFSET
	var half_height: float = tex.get_height() / 2.0 if sprite.centered else 0.0
	var top: float = sprite.position.y + sprite.offset.y - half_height
	if not sprite.centered:
		top = sprite.position.y + sprite.offset.y
	return Vector2(sprite.position.x + sprite.offset.x + (0.0 if sprite.centered else tex.get_width() / 2.0), top - HEAD_GAP)

func _set_icon(bubble: Node2D, icon: String) -> void:
	if not is_instance_valid(bubble) or not _cells.has(icon):
		return
	bubble.cell_index = _cells[icon]
	bubble.queue_redraw()

## One bubble: a box with a tail pointing down at the head, and the icon inside.
## Origin is the tail's tip.
class _Bubble extends Node2D:
	var texture: Texture2D
	var cell: int = 16
	var cell_index: int = 0

	func _draw() -> void:
		var pad: float = PictureBubbles.PADDING
		var w: float = cell + pad * 2.0
		var h: float = cell + pad * 2.0
		var tail_h: float = PictureBubbles.TAIL_HEIGHT
		var half: float = PictureBubbles.TAIL_HALF_WIDTH
		var box := Rect2(-w / 2.0, -tail_h - h, w, h)
		# Body with the corners clipped by a pixel, so it reads as rounded.
		draw_rect(box.grow(-1.0), PictureBubbles.FILL)
		draw_rect(Rect2(box.position.x + 1.0, box.position.y, box.size.x - 2.0, box.size.y), PictureBubbles.FILL)
		draw_rect(Rect2(box.position.x, box.position.y + 1.0, box.size.x, box.size.y - 2.0), PictureBubbles.FILL)
		var e := PictureBubbles.EDGE
		draw_line(Vector2(box.position.x + 1.0, box.position.y + 0.5), Vector2(box.end.x - 1.0, box.position.y + 0.5), e, 1.0)
		draw_line(Vector2(box.position.x + 1.0, box.end.y - 0.5), Vector2(-half, box.end.y - 0.5), e, 1.0)
		draw_line(Vector2(half, box.end.y - 0.5), Vector2(box.end.x - 1.0, box.end.y - 0.5), e, 1.0)
		draw_line(Vector2(box.position.x + 0.5, box.position.y + 1.0), Vector2(box.position.x + 0.5, box.end.y - 1.0), e, 1.0)
		draw_line(Vector2(box.end.x - 0.5, box.position.y + 1.0), Vector2(box.end.x - 0.5, box.end.y - 1.0), e, 1.0)
		# Tail.
		var top_y: float = box.end.y - 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(-half, top_y), Vector2(half, top_y), Vector2(0, 0)]), PictureBubbles.FILL)
		draw_line(Vector2(-half, box.end.y - 0.5), Vector2(0, -0.5), e, 1.0)
		draw_line(Vector2(half, box.end.y - 0.5), Vector2(0, -0.5), e, 1.0)
		# Icon.
		if texture != null:
			var src := Rect2(cell_index * cell, 0, cell, cell)
			draw_texture_rect_region(texture, Rect2(box.position + Vector2(pad, pad), Vector2(cell, cell)), src)
