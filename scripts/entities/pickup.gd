# pickup.gd -- something the player can pick up for a side quest: a soft
# pulsing glint on the floor, "Pick up" when close. Taking it adds the item
# (data/items.json) to the inventory, sets "pickup_<id>_taken", and says one
# line ("You found Rose's notebook."). It only shows while its quest wants it:
# requires_flag set (usually the quest's accepted flag), unless_flag not set
# (the quest's done flag), and not taken yet. Placed from data/culture_spots.json
# "pickups" (culture_spots.gd), so no level scene needs editing.
extends Node2D

const INTERACTABLE := preload("res://scenes/components/interactable_component.tscn")
const GLINT := Color(1.0, 0.93, 0.62)

var pickup_id: String = ""
var item_id: String = ""
var requires_flag: String = ""
var unless_flag: String = ""
## Line shown on pickup; empty = "You found <item name>."
var found_text: String = ""

var _ic: Node2D
var _t: float = 0.0

func _ready() -> void:
	_ic = INTERACTABLE.instantiate()
	_ic.interact_label = "Pick up"
	_ic.area_size = Vector2(16, 16)
	_ic.position = Vector2(8, -8)
	add_child(_ic)
	_ic.interacted.connect(_on_interacted)
	GameState.flag_changed.connect(func(_flag: String, _value: bool): _refresh())
	_refresh()

func _taken_flag() -> String:
	return "pickup_%s_taken" % pickup_id

func is_available() -> bool:
	if GameState.get_flag(_taken_flag()):
		return false
	if not requires_flag.is_empty() and not GameState.get_flag(requires_flag):
		return false
	return unless_flag.is_empty() or not GameState.get_flag(unless_flag)

func _refresh() -> void:
	var on: bool = is_available()
	visible = on
	_ic.disabled = not on
	set_process(on)
	if on:
		TutorialManager.start("pickup")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

## A four-point twinkle that grows and fades, centred on the tile.
func _draw() -> void:
	var c := Vector2(8, -8)
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var size: float = 5.0 + 3.0 * pulse
	var col := GLINT
	col.a = 0.75 + 0.25 * pulse
	# Dark outline first so it reads on light floors and in dim rooms alike.
	var outline := Color(0.23, 0.16, 0.16, 0.8)
	draw_line(c + Vector2(0, -size - 1), c + Vector2(0, size + 1), outline, 3.0)
	draw_line(c + Vector2(-size - 1, 0), c + Vector2(size + 1, 0), outline, 3.0)
	draw_circle(c, 3.0 + pulse, outline)
	draw_line(c + Vector2(0, -size), c + Vector2(0, size), col, 1.0)
	draw_line(c + Vector2(-size, 0), c + Vector2(size, 0), col, 1.0)
	draw_circle(c, 2.0 + pulse, col)

func _on_interacted(_interactor: Node) -> void:
	if not is_available() or CutsceneManager.is_playing() or DialogueUI.is_active():
		return
	GameState.add_item(item_id)
	GameState.set_flag(_taken_flag())
	GameState.save_game()
	AudioManager.play_sfx("menu_click")
	var text: String = found_text if not found_text.is_empty() \
			else "You found %s." % Economy.item_name(item_id).to_lower()
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = [{"speaker": "", "text": text, "next": null}]
	add_child(dialogue)
	dialogue.dialogue_ended.connect(dialogue.queue_free)
	dialogue.start_dialogue()
