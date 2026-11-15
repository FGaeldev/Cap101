# seat.gd -- a single spot a character can sit: chairs, armchairs, stools,
# benches painted into the tilemap. No art of its own; the furniture is whatever
# is drawn underneath. Put seat.tscn where a character standing on the
# furniture's tile would have their origin (bottom-left corner of that tile,
# like every actor), then set:
#   sit_offset   nudge for where a seated character's origin goes, e.g.
#                (0, -8) for a bench that should hide their legs
#   face         which way they face while seated
#   stand_offset where they walk in from and get up to by default
#   sprite_lift  extra pixels their sprite moves up while seated
# The editor draws the seated spot (filled) and the stand spot (outline).
# While another character (an NPC sitting there by schedule, say) is on the
# seat's tile, the "Sit" interact is hidden.
#
# Same API as pew.gd, so the player, Game.gd and the "sit"/"stand" cutscene
# actions treat both alike (a seat is a one-seat pew; the seat index is
# ignored):
#   seat.sit(actor)                  # instantly
#   seat.walk_to_seat(actor, 0, mgr) # walk to the stand spot, then sit
#   seat.stand(actor)                # back to the stand spot
#   seat.stand(actor, Vector2.LEFT)  # out to the left, if that tile is free
# Outside cutscenes the player sits with the "Sit" interact and pressing any
# direction gets them up that way (player.gd get_input_dir()).
# While seated the actor's collision shape is off (the furniture is usually
# solid), and leaving the level stands them up.
@tool
extends Node2D

const TILE: int = 16
const DIRECTIONS := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
const ActorPath := preload("res://scripts/util/actor_path.gd")
## Seconds the player takes to slide into the seat after interacting.
const PLAYER_SIT_TIME: float = 0.2

## Where a seated character's origin (their feet) goes, relative to this node.
@export var sit_offset: Vector2 = Vector2.ZERO:
	set(value):
		sit_offset = value
		_refresh()
## Which way seated characters face.
@export_enum("up", "down", "left", "right") var face: String = "down":
	set(value):
		face = value
		_refresh()
## Where characters walk in from and get up to, relative to this node.
@export var stand_offset: Vector2 = Vector2(0, 16):
	set(value):
		stand_offset = value
		_refresh()
## Pixels a seated character's sprite moves up.
@export var sprite_lift: int = 0
## Size of the "Sit" interact box, centred on the seat's tile. 24 reaches a few
## pixels into each neighbouring tile, so the player can sit from any side.
@export var area_size: Vector2 = Vector2(24, 24):
	set(value):
		area_size = value
		_refresh()

## Seconds between checks for someone else sitting here.
const OCCUPIED_CHECK: float = 0.25

var _seated: Node2D = null
var _slide: Tween
var _check_timer: float = 0.0

func _ready() -> void:
	_refresh()
	if Engine.is_editor_hint():
		set_process(false)
	else:
		add_to_group("seats")
		$InteractableComponent.interacted.connect(_on_interacted)

func _refresh() -> void:
	var interactable := get_node_or_null("InteractableComponent")
	if interactable:
		interactable.position = _seat_cell_local() + Vector2(TILE / 2.0, -TILE / 2.0)
		interactable.area_size = area_size
	queue_redraw()

## Origin of the tile the seated spot is on, relative to this node.
func _seat_cell_local() -> Vector2:
	return (sit_offset / TILE).round() * TILE

## Hides the "Sit" interact while another character is on the seat's tile.
func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = OCCUPIED_CHECK
	if _seated != null and is_instance_valid(_seated):
		# An NPC seated through sit() (a cutscene "sit" step) also blocks the seat.
		$InteractableComponent.disabled = not _seated.is_in_group("player")
	else:
		$InteractableComponent.disabled = _taken_by_other()

## True if a character other than the player stands or sits on the seat's tile.
func _taken_by_other() -> bool:
	var level: Node = owner if owner != null else get_parent()
	var cell: Vector2 = global_position + _seat_cell_local()
	for body: Node in level.find_children("*", "CharacterBody2D", true, false):
		if body.is_in_group("player") or not body is Node2D:
			continue
		if (body as Node2D).global_position.distance_to(cell) < TILE * 0.6:
			return true
	return false

## Editor-only guide: filled tile = seated spot with an arrow for `face`,
## outlined tile = stand spot.
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var sit_rect := Rect2(sit_offset + Vector2(0, -TILE), Vector2(TILE, TILE))
	draw_rect(sit_rect, Color(0.2, 0.8, 1.0, 0.35))
	var c := sit_rect.get_center()
	draw_line(c, c + DIRECTIONS.get(face, Vector2.DOWN) * 7.0, Color(0.2, 0.8, 1.0), 1.0)
	draw_rect(Rect2(stand_offset + Vector2(0, -TILE), Vector2(TILE, TILE)), Color(1.0, 0.8, 0.2, 0.9), false, 1.0)

func _on_interacted(interactor: Node = null) -> void:
	var player := interactor as Node2D
	if player == null or player.has_meta("pew") or _taken_by_other():
		return
	var from: Vector2 = player.global_position
	if not sit(player):
		return
	# sit() put them on the seat; slide there from where they stood instead.
	var to: Vector2 = player.global_position
	player.global_position = from
	_slide = player.create_tween()
	_slide.tween_property(player, "global_position", to, PLAYER_SIT_TIME)

func seat_position(_seat: int = 0) -> Vector2:
	return global_position + sit_offset

func approach_position(_seat: int = 0) -> Vector2:
	return global_position + stand_offset

## Where someone seated counts as standing, e.g. for a saved position.
func standing_spot(_actor: Node = null) -> Vector2:
	return approach_position()

func seat_count() -> int:
	return 1

func is_free(seat: int = 0) -> bool:
	return seat <= 0 and _seated == null

func free_seat() -> int:
	return 0 if _seated == null else -1

func nearest_free_seat(_x: float = 0.0) -> int:
	return free_seat()

func seat_of(actor: Node) -> int:
	return 0 if actor != null and actor == _seated else -1

## Seats `actor` at once. Returns false if someone else is sitting here.
func sit(actor: Node2D, _seat: int = -1) -> bool:
	if actor == null or (_seated != null and _seated != actor):
		return false
	# Get them off any other seat or pew first.
	if actor.has_meta("pew") and actor.get_meta("pew") != self and is_instance_valid(actor.get_meta("pew")):
		actor.get_meta("pew")._release(actor)
	_seated = actor
	actor.set_meta("pew", self)
	actor.global_position = seat_position()
	var sprite: Node2D = actor.get_node_or_null("AnimatedSprite2D")
	if sprite and not actor.has_meta("pew_sprite_y"):
		actor.set_meta("pew_sprite_y", sprite.position.y)
		sprite.position.y -= sprite_lift
	var body: CollisionShape2D = actor.get_node_or_null("CollisionShape2D")
	if body and not actor.has_meta("pew_shape_disabled"):
		actor.set_meta("pew_shape_disabled", body.disabled)
		body.set_deferred("disabled", true)
	_set_anim(actor, "idle", DIRECTIONS.get(face, Vector2.DOWN))
	return true

## Walks `actor` around obstacles to the stand spot, steps onto the seat and
## sits. `mgr` is CutsceneManager. Returns false if it couldn't sit.
func walk_to_seat(actor: Node2D, _seat: int, mgr: Node, speed: float = 40.0) -> bool:
	if not is_free():
		return false
	var run: int = mgr.current_run()
	var start: Vector2 = (actor.global_position / TILE).round() * TILE
	actor.global_position = start
	var legs: Array[Vector2] = ActorPath.around_actors(mgr, actor, start, approach_position())
	legs.append(seat_position())
	for leg_end in legs:
		var dir: Vector2 = (leg_end - actor.global_position).normalized()
		_set_anim(actor, "walk", dir)
		var tween: Tween = mgr.track_tween(actor.create_tween())
		tween.tween_property(actor, "global_position", leg_end, actor.global_position.distance_to(leg_end) / speed)
		await tween.finished
		if not mgr.is_run_current(run) or not is_instance_valid(actor):
			return false
	return sit(actor)

## Gets `actor` up. With `toward` they step to the tile next to the seat that
## way if it's free; otherwise (or with no direction) to the stand spot.
func stand(actor: Node2D, toward: Vector2 = Vector2.ZERO) -> void:
	if seat_of(actor) < 0:
		return
	_release(actor)
	var spot := approach_position()
	if toward != Vector2.ZERO:
		var beside: Vector2 = global_position + _seat_cell_local() + toward.normalized() * TILE
		if not ActorPath._is_solid(actor, beside):
			spot = beside
	actor.global_position = spot
	var facing := toward if toward != Vector2.ZERO else (spot - seat_position()).normalized()
	_set_anim(actor, "idle", facing if facing != Vector2.ZERO else Vector2.DOWN)

## Undoes everything sit() changed on `actor` and frees the seat.
func _release(actor: Node) -> void:
	if actor == _seated:
		_seated = null
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
	if is_instance_valid(_seated):
		_release(_seated)
	_seated = null

func _set_anim(actor: Node, state: String, dir: Vector2) -> void:
	if actor.has_method("update_facing"):
		actor.update_facing(dir)
	var anim = actor.get_node_or_null("CutsceneAnimComponent")
	if anim:
		anim.set_cutscene_anim_state(state, dir)
