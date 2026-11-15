# pew.gd -- a church pew that characters can sit on.
#
# Place the pew with its origin on the top-left corner of the bench tile and set
# `seats` to its width in tiles; the art redraws itself in the editor. One seat
# per tile: a seated character's origin goes `SEAT_Y` px below the pew's origin,
# they face `face` (up, toward the altar), and their sprite is lifted `SIT_LIFT`
# pixels. The bench draws in front of them, hiding them from the hips down like
# a pew back does. They walk in from, and get up to, the free row behind it.
#
# Seating is done from code or cutscenes (the "sit" and "stand" actions):
#   pew.sit(actor)            # first free seat, instantly
#   pew.sit(actor, 1)         # a given seat
#   pew.walk_to_seat(actor, 1, mgr)   # walk in from the row behind, then sit
#   pew.stand(actor)          # back up into the row behind, collision restored
#   pew.stand(actor, Vector2.DOWN)    # or out to the row in front, if it's free
# Outside cutscenes the player can sit too: the pew's "Sit" interact seats them
# on the nearest free seat, and pressing any direction gets them up that way
# (player.gd get_input_dir()).
# While seated, an actor's collision shape is off (the seat tile is solid), and
# leaving the level stands everyone up so the persistent player isn't left
# ghosting through walls.
@tool
extends StaticBody2D

const TILE: int = 16
## How many pixels a seated character's sprite moves up.
const SIT_LIFT: int = 1
## Indoors.png bench tiles: left end, middle, right end.
const ART_LEFT := Vector2i(9, 10)
const ART_MID := Vector2i(10, 10)
const ART_RIGHT := Vector2i(11, 10)
## Top and bottom of the bench art inside its tile, for the collision box.
const BENCH_TOP: int = 3
const BENCH_BOTTOM: int = 15
## A seated character's origin, pew-local y. Half a tile down: the bench covers
## them from the hips down. A full tile (the bench's own cell) leaves only their
## hair showing.
const SEAT_Y: int = 8
## The bench sorts at this y (pew-local): after a seated character's origin
## (SEAT_Y) so it covers their legs, before someone standing in the row in front
## (y 32) so it never covers their head.
const SORT_Y: int = 24
const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}

const ActorPath := preload("res://scripts/util/actor_path.gd")

## Width in tiles; one seat per tile. 1 = a single-tile bench.
@export_range(1, 12) var seats: int = 3:
	set(value):
		seats = value
		if is_node_ready():
			_build()
## Which way seated characters face.
@export_enum("up", "down", "left", "right") var face: String = "up"

@onready var _art: Node2D = $Art
@onready var _tiles: TileMapLayer = $Art/Tiles
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _interactable: InteractableComponent = $InteractableComponent

## seat index -> seated actor
var _seated: Dictionary = {}

## Seconds the player takes to slide into a seat after interacting.
const PLAYER_SIT_TIME: float = 0.2
## The player's slide into a seat; stopped if they get up before it ends.
var _slide: Tween

func _ready() -> void:
	_build()
	if not Engine.is_editor_hint():
		add_to_group("pews")
		_interactable.interacted.connect(_on_interacted)

func _build() -> void:
	_art.position = Vector2(0, SORT_Y)
	_tiles.position = Vector2(0, -SORT_Y)
	_tiles.clear()
	for i in seats:
		var art := ART_MID
		if seats > 1 and i == 0:
			art = ART_LEFT
		elif seats > 1 and i == seats - 1:
			art = ART_RIGHT
		_tiles.set_cell(Vector2i(i, 0), 0, art)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(seats * TILE, BENCH_BOTTOM - BENCH_TOP)
	_shape.shape = rect
	_shape.position = Vector2(seats * TILE / 2.0, (BENCH_TOP + BENCH_BOTTOM) / 2.0)
	# "Sit" spot: the bench plus the free row behind it and the row in front.
	var interactable := get_node_or_null("InteractableComponent")
	if interactable:
		interactable.position = Vector2(seats * TILE / 2.0, TILE / 2.0)
		interactable.area_size = Vector2(seats * TILE, TILE * 3)

## The player interacted: sit in the seat nearest them. Moving gets them up
## again (player.gd get_input_dir()).
func _on_interacted(interactor: Node = null) -> void:
	var player := interactor as Node2D
	if player == null or player.has_meta("pew"):
		return
	var seat := nearest_free_seat(player.global_position.x)
	if seat < 0:
		return
	var from: Vector2 = player.global_position
	if not sit(player, seat):
		return
	# sit() put them on the seat; slide there from where they stood instead.
	var to: Vector2 = player.global_position
	player.global_position = from
	_slide = player.create_tween()
	_slide.tween_property(player, "global_position", to, PLAYER_SIT_TIME)

## Free seat closest to global x `x`, or -1 if the pew is full.
func nearest_free_seat(x: float) -> int:
	var best := -1
	for i in seats:
		if _seated.has(i):
			continue
		if best < 0 or absf(seat_position(i).x - x) < absf(seat_position(best).x - x):
			best = i
	return best

## Where an actor stands (global origin) to sit in `seat`.
func seat_position(seat: int) -> Vector2:
	return global_position + Vector2(seat * TILE, SEAT_Y)

## The free tile directly behind `seat` (the row above the bench), where
## characters step in from and get up to.
func approach_position(seat: int) -> Vector2:
	return global_position + Vector2(seat * TILE, 0)

func seat_count() -> int:
	return seats

func is_free(seat: int) -> bool:
	return seat >= 0 and seat < seats and not _seated.has(seat)

## First free seat, or -1 if the pew is full.
func free_seat() -> int:
	for i in seats:
		if not _seated.has(i):
			return i
	return -1

## Seat of `actor` on this pew, or -1.
func seat_of(actor: Node) -> int:
	for i in _seated:
		if _seated[i] == actor:
			return i
	return -1

## Seats `actor` at once. seat -1 = first free seat. Returns false if the
## seat is taken or out of range.
func sit(actor: Node2D, seat: int = -1) -> bool:
	if actor == null:
		return false
	if seat < 0:
		seat = free_seat()
	if seat < 0 or (not is_free(seat) and seat_of(actor) != seat):
		return false
	_release(actor)
	_seated[seat] = actor
	actor.set_meta("pew", self)
	actor.global_position = seat_position(seat)
	var sprite: Node2D = actor.get_node_or_null("AnimatedSprite2D")
	if sprite and not actor.has_meta("pew_sprite_y"):
		actor.set_meta("pew_sprite_y", sprite.position.y)
		sprite.position.y -= SIT_LIFT
	var body: CollisionShape2D = actor.get_node_or_null("CollisionShape2D")
	if body and not actor.has_meta("pew_shape_disabled"):
		actor.set_meta("pew_shape_disabled", body.disabled)
		body.set_deferred("disabled", true)
	_set_anim(actor, "idle", DIRECTIONS.get(face, Vector2.UP))
	return true

## Walks `actor` around obstacles to the tile behind `seat`, steps onto the
## seat and sits. `mgr` is CutsceneManager (tweens are tracked so an abort
## stops them). Returns false if it couldn't sit.
func walk_to_seat(actor: Node2D, seat: int, mgr: Node, speed: float = 40.0) -> bool:
	if seat < 0:
		seat = free_seat()
	if not is_free(seat):
		return false
	var run: int = mgr.current_run()
	var start: Vector2 = (actor.global_position / TILE).round() * TILE
	actor.global_position = start
	var legs: Array[Vector2] = ActorPath.around_actors(mgr, actor, start, approach_position(seat))
	legs.append(seat_position(seat))
	for leg_end in legs:
		var dir: Vector2 = (leg_end - actor.global_position).normalized()
		_set_anim(actor, "walk", dir)
		var tween: Tween = mgr.track_tween(actor.create_tween())
		tween.tween_property(actor, "global_position", leg_end, actor.global_position.distance_to(leg_end) / speed)
		await tween.finished
		if not mgr.is_run_current(run) or not is_instance_valid(actor):
			return false
	return sit(actor, seat)

## Gets `actor` up. `toward` picks the side: down = the row in front of the pew
## (if it's free), anything else = the free row behind it. They face `toward`.
func stand(actor: Node2D, toward: Vector2 = Vector2.UP) -> void:
	var seat := seat_of(actor)
	if seat < 0:
		return
	_release(actor)
	var spot := approach_position(seat)
	if toward.y > 0:
		var front := front_position(seat)
		if not ActorPath._is_solid(actor, front):
			spot = front
	actor.global_position = spot
	_set_anim(actor, "idle", toward if toward != Vector2.ZERO else Vector2.UP)

## The tile in front of `seat` (the row below the bench).
func front_position(seat: int) -> Vector2:
	return global_position + Vector2(seat * TILE, 2 * TILE)

## Where someone seated should count as standing, e.g. for a saved position:
## the row behind their seat, since the seat itself is off the tile grid.
func standing_spot(actor: Node) -> Vector2:
	var seat := seat_of(actor)
	return approach_position(seat) if seat >= 0 else (actor as Node2D).global_position

## Undoes everything sit() changed on `actor` and frees its seat.
func _release(actor: Node) -> void:
	var seat := seat_of(actor)
	if seat >= 0:
		_seated.erase(seat)
	if _slide and _slide.is_valid():
		_slide.kill()
	if not is_instance_valid(actor):
		return
	if actor.has_meta("pew") and actor.get_meta("pew") == self:
		actor.remove_meta("pew")
	var sprite: Node2D = actor.get_node_or_null("AnimatedSprite2D")
	if sprite and actor.has_meta("pew_sprite_y"):
		sprite.position.y = actor.get_meta("pew_sprite_y")
		actor.remove_meta("pew_sprite_y")
	var body: CollisionShape2D = actor.get_node_or_null("CollisionShape2D")
	if body and actor.has_meta("pew_shape_disabled"):
		body.set_deferred("disabled", actor.get_meta("pew_shape_disabled"))
		actor.remove_meta("pew_shape_disabled")

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	for actor in _seated.values().duplicate():
		if is_instance_valid(actor):
			_release(actor)
	_seated.clear()

func _set_anim(actor: Node, state: String, dir: Vector2) -> void:
	# The player keeps its own facing; update it so it still faces this way
	# once its idle state takes over again.
	if actor.has_method("update_facing"):
		actor.update_facing(dir)
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state, dir)
