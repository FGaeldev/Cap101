# weave_hang.gd -- "Help hang the weaves" in the Haboean loom house (v1.1.9,
# tester report: Chapter 3 is only weaving). Played in the room itself: the
# curator's new piña weaves lie folded on the floor by the door; the player picks
# one up (it rides above their head), walks to a wide display case and hangs it.
# Each case in the round has a sign with a colour in Akeanon (puea, asul, ...),
# so finding the right case is reading the word. A wrong case is a miss.
#
# daily_games.gd starts it from the curator's menu ("world": "weave_hang") and
# awaits finished(result): "won", "lost" (more than MAX_MISSES misses) or
# "cancelled" (the player left the room). The round tidies itself up either way.
#
# Art: the indoors tileset (Indoors.png). The room's cases are the empty case
# tile (41-42, 18-19); a hung weave draws that colour's filled case over it, and
# a folded weave is its swatch tile in row 16. See COLORS.
extends Node2D

signal finished(result: String)

const INTERACTABLE := preload("res://scenes/components/interactable_component.tscn")
const SHEET := preload("res://assets/tilesets/Indoors.png")
const TILE: float = 16.0
const MAX_MISSES: int = 3
## Where the case's top tile sorts: its centre (8) plus its y_sort_origin in
## indoors.tres (40), plus one so the cloth sorts
## just after the case (a tie goes to the tiles).
const CASE_SORT_Y: float = 49.0

## Colour -> word id, its filled case (top-left tile, 2x2) and folded swatch tile
## in Indoors.png.
const COLORS: Array = [
	{"id": "puea", "word": "w198", "case": Vector2i(39, 14), "fold": Vector2i(33, 16)},
	{"id": "berde", "word": "w038", "case": Vector2i(39, 16), "fold": Vector2i(34, 16)},
	{"id": "asul", "word": "w021", "case": Vector2i(39, 18), "fold": Vector2i(35, 16)},
	{"id": "puti", "word": "w199", "case": Vector2i(41, 14), "fold": Vector2i(36, 16)},
	{"id": "itom", "word": "w094", "case": Vector2i(41, 16), "fold": Vector2i(37, 16)},
	{"id": "dueaw", "word": "w056", "case": Vector2i(37, 18), "fold": Vector2i(38, 16)},
]
## The eight wide display cases (two tiles wide), by their top-left tile, read
## from haboean_gallery.tscn's Objects layer.
const CASES: Array[Vector2i] = [
	Vector2i(1, 10), Vector2i(5, 10), Vector2i(9, 10), Vector2i(13, 10),
	Vector2i(1, 13), Vector2i(5, 13), Vector2i(9, 13), Vector2i(13, 13),
]
## Where the folded weaves are laid out: open floor by the door, every other tile.
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(6, 20), Vector2i(8, 20), Vector2i(10, 20), Vector2i(12, 20),
	Vector2i(6, 19), Vector2i(8, 19), Vector2i(10, 19), Vector2i(12, 19),
]


## A folded weave on the floor (position = bottom-left of its tile).
class Fabric extends Node2D:
	var info: Dictionary = {}
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_texture_rect_region(SHEET, Rect2(0, -16, 16, 16), Rect2(Vector2(info["fold"]) * 16.0, Vector2(16, 16)))
		# Same soft glint as side-quest pickups, so it reads as "take me".
		var a: float = 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(13, -12), 1.0 + a, Color(1.0, 0.93, 0.62, 0.6 + 0.4 * a))

## A display case taking part in the round: its sign and, once hung, the filled
## case drawn over the empty one. position = case top-left + (0, CASE_SORT_Y).
class Case extends Node2D:
	var info: Dictionary = {}
	var hung: bool = false
	var sort_y: float = 0.0

	func _draw() -> void:
		if hung:
			draw_texture_rect_region(SHEET, Rect2(0, -sort_y, 32, 32), Rect2(Vector2(info["case"]) * 16.0, Vector2(32, 32)))

## What the player is holding, drawn over their head.
class Carried extends Node2D:
	var fold: Vector2i = Vector2i.ZERO
	func _draw() -> void:
		draw_texture_rect_region(SHEET, Rect2(-8, -38, 16, 16), Rect2(Vector2(fold) * 16.0, Vector2(16, 16)))

var _cases: Array = []      # [Case]
var _fabrics: Array = []    # [Fabric]
var _carrying: Dictionary = {}
var _carried: Carried = null
var _hung: int = 0
var _misses: int = 0
var _done: bool = false
var _status: CanvasLayer = null
var _status_label: Label = null
var _muted: Array = []      # examinable interactables switched off for the round


func _ready() -> void:
	tree_exiting.connect(_on_exiting)
	y_sort_enabled = true  # children sort with the room (cases, folded weaves)
	var tier: int = GameState.get_difficulty_tier()
	var count: int = clampi(3 + tier, 3, COLORS.size())
	var colors: Array = COLORS.duplicate()
	colors.shuffle()
	colors = colors.slice(0, count)
	var spots: Array = CASES.duplicate()
	spots.shuffle()
	var floor_spots: Array = FLOOR_TILES.duplicate()
	floor_spots.shuffle()
	for i in colors.size():
		_add_case(colors[i], spots[i])
		_add_fabric(colors[i], floor_spots[i])
	_mute_examinables(true)
	_build_status()
	_refresh_status()

func _add_case(info: Dictionary, tile: Vector2i) -> void:
	var c := Case.new()
	c.info = info
	c.sort_y = CASE_SORT_Y
	# Sorted like the case's own top tile (indoors.tres y_sort_origin 40) and added
	# after it, so the hung weave and sign draw over the case and sort like it with people.
	c.position = Vector2(tile) * TILE + Vector2(0, CASE_SORT_Y)
	add_child(c)
	_cases.append(c)
	# Sign over the case, the colour in Akeanon.
	var sign := Label.new()
	sign.text = str(WordBank.words.get(str(info["word"]), {}).get("akeanon", info["id"]))
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.size = Vector2(48, 10)
	sign.position = Vector2(-8, -3 - CASE_SORT_Y)
	sign.add_theme_font_size_override("font_size", 8)
	sign.add_theme_color_override("font_color", Color.WHITE)
	sign.add_theme_color_override("font_outline_color", Color(0.23, 0.16, 0.16))
	sign.add_theme_constant_override("outline_size", 3)
	c.add_child(sign)
	# Interact from the floor row just below the case.
	var ic: Node2D = INTERACTABLE.instantiate()
	ic.interact_label = "Hang"
	ic.area_size = Vector2(32, 16)
	ic.position = Vector2(16, 2.5 * TILE - CASE_SORT_Y)  # the floor row just below the case
	c.add_child(ic)
	ic.interacted.connect(_on_case.bind(c))

func _add_fabric(info: Dictionary, tile: Vector2i) -> void:
	var f := Fabric.new()
	f.info = info
	f.position = Vector2(tile) * TILE + Vector2(0, TILE)
	add_child(f)
	_fabrics.append(f)
	var ic: Node2D = INTERACTABLE.instantiate()
	ic.interact_label = "Pick up"
	ic.area_size = Vector2(16, 16)
	ic.position = Vector2(8, -8)
	f.add_child(ic)
	ic.interacted.connect(_on_fabric.bind(f))

# --- play ----------------------------------------------------------------------

func _busy() -> bool:
	return _done or CutsceneManager.is_playing() or DialogueUI.is_active()

func _on_fabric(_who: Node, f: Fabric) -> void:
	if _busy() or not is_instance_valid(f):
		return
	if not _carrying.is_empty():
		_say("My hands are full. Hang this one first.")
		return
	AudioManager.play_sfx("menu_click")
	_carrying = f.info
	_fabrics.erase(f)
	f.queue_free()
	var player: Node2D = CutsceneManager.get_actor("player")
	if player != null:
		_carried = Carried.new()
		_carried.fold = _carrying["fold"]
		player.add_child(_carried)
	_refresh_status()

func _on_case(_who: Node, c: Case) -> void:
	if _busy() or c.hung:
		return
	Economy.expose_line_words({"word_ids": [str(c.info["word"])]})
	if _carrying.is_empty():
		_say("A display for %s weaves. The new ones are on the floor by the door." % _word(c.info))
		return
	if c.info["id"] == _carrying["id"]:
		AudioManager.play_sfx("advance")
		c.hung = true
		c.queue_redraw()
		GameState.adjust_mastery(str(c.info["word"]), 1)
		_drop_carried()
		_hung += 1
		_refresh_status()
		if _hung >= _cases.size():
			_finish("won")
		return
	AudioManager.play_sfx("menu_click")
	_misses += 1
	_refresh_status()
	if _misses > MAX_MISSES:
		_finish("lost")
		return
	_say("This one says %s. That's not this weave's colour." % _word(c.info))

func _word(info: Dictionary) -> String:
	return str(WordBank.words.get(str(info["word"]), {}).get("akeanon", info["id"]))

func _drop_carried() -> void:
	_carrying = {}
	if is_instance_valid(_carried):
		_carried.queue_free()
	_carried = null

func _say(text: String) -> void:
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "Player", "text": text, "next": null}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()

# --- status and clean-up --------------------------------------------------------

func _build_status() -> void:
	_status = CanvasLayer.new()
	_status.layer = 5
	add_child(_status)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_header_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 40
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(panel)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_XS)
	_status_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	panel.add_child(_status_label)

func _refresh_status() -> void:
	if _status_label == null:
		return
	var holding: String = "  ·  Carrying a weave" if not _carrying.is_empty() else ""
	_status_label.text = "Weaves hung %d/%d  ·  Misses %d/%d%s" % [_hung, _cases.size(), _misses, MAX_MISSES, holding]

## The gallery's own exhibits stand beside some cases: keep "Look" out of the way.
func _mute_examinables(on: bool) -> void:
	if on:
		for n: Node in get_parent().get_children():
			if n == self or not n.get("scene_key") is String:
				continue
			var ic: Node = n.get_node_or_null("InteractableComponent")
			if ic == null:
				for child in n.get_children():
					if child is InteractableComponent:
						ic = child
			if ic != null and not ic.disabled:
				ic.disabled = true
				_muted.append(ic)
	else:
		for ic in _muted:
			if is_instance_valid(ic):
				ic.disabled = false
		_muted.clear()

func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	_drop_carried()
	_mute_examinables(false)
	if is_instance_valid(_status):
		_status.queue_free()
	# The hung weaves stay up until the player leaves the room.
	for f in _fabrics:
		if is_instance_valid(f):
			f.queue_free()
	_fabrics.clear()
	if result != "won":
		for c in _cases:
			if is_instance_valid(c):
				c.queue_free()
	finished.emit(result)

func _on_exiting() -> void:
	if not _done:
		_finish("cancelled")
