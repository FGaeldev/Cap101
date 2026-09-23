# InteractableComponent — attach to any Node2D to make it interactable
# Parent must have Area2D child named "InteractArea"
class_name InteractableComponent
extends Node2D

signal interacted(interactor: Node)

@export var interact_label: String = "Talk"
## Optional. If set, fires QuestManager.complete_quests_with_trigger(trigger_on_enter)
## once when player enters this InteractArea. Empty = no trigger (default, most NPCs).
@export var trigger_on_enter: String = ""
var _in_range: bool = false
var _player_ref: Node = null

# Global pool of currently in-range interactables, across ALL instances.
# HUD's interact button (hud.gd) reads this to find the nearest one to the
# player without HUD needing a per-NPC reference — same "register on ready,
# read from a shared spot" spirit as CutsceneManager's actor registry, but
# static since this needs no autoload node, just shared data.
static var _in_range_pool: Array[InteractableComponent] = []

func _ready() -> void:
	# Expects sibling Area2D named InteractArea on parent
	var area = $InteractArea
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		area.input_event.connect(_on_input_event)

func interact() -> void:
	if not _in_range:
		return

	interacted.emit()

func _exit_tree() -> void:
	# Covers despawn/free while still in range (edge case) -- without this
	# a freed instance would sit as a dangling entry in the static pool.
	_in_range_pool.erase(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		try_interact()

func _on_input_event(_viewport, event, _shape_idx):
	# project.godot sets pointing/emulate_touch_from_mouse=true (needed for
	# Android), which makes a single mouse click also synthesize an
	# InputEventScreenTouch. Checking both event types here double-fired
	# `interacted` per click. Touch alone covers real touch AND the
	# emulated-from-mouse case, so this is the single source now.
	if event is InputEventScreenTouch and event.pressed:
		try_interact()

## Single guarded entry point for firing `interacted` -- shared by keyboard
## input, touch/click input, AND the HUD interact button (hud.gd), so all
## three paths get the exact same range/cutscene/visibility checks instead
## of the button needing its own copy of the guard logic.
func try_interact() -> void:
	if not _in_range or CutsceneManager.is_playing():
		return
	if not get_parent().is_visible_in_tree():
		return
	TutorialManager.notify("interacted")
	interacted.emit(_player_ref)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = true
		_player_ref = body
		if not _in_range_pool.has(self):
			_in_range_pool.append(self)
		if not trigger_on_enter.is_empty():
			QuestManager.complete_quests_with_trigger(trigger_on_enter)
		TutorialManager.notify("interactable_in_range")
		# TODO: show interact prompt UI

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_in_range = false
		_player_ref = null
		_in_range_pool.erase(self)

## Nearest in-range interactable to `from_pos`, or null if none in range.
## HUD calls this every frame it's visible -- pool is small (NPCs/objects
## actually within interact radius at once), no spatial index needed.
static func get_nearest(from_pos: Vector2) -> InteractableComponent:
	var nearest: InteractableComponent = null
	var best_dist := INF
	for ic in _in_range_pool:
		if not is_instance_valid(ic):
			continue
		var d: float = ic.get_parent().global_position.distance_squared_to(from_pos)
		if d < best_dist:
			best_dist = d
			nearest = ic
	return nearest
