# scripts/components/Comp_CutsceneAnim.gd
# Sibling component, same pattern as InteractableComponent/DialogueComponent.
# Drives an AnimatedSprite2D during cutscene moves. Attach only to actors that
# actually move in cutscenes (Father) -- static NPCs (Lola) don't need it.
class_name CutsceneAnimComponent
extends Node

@export var sprite: AnimatedSprite2D
var _last_dir: Vector2 = Vector2(0, 1)  # default facing down; remembers heading for idle

func set_cutscene_anim_state(state: String, dir: Vector2 = Vector2.ZERO) -> void:
	if dir != Vector2.ZERO:
		_last_dir = dir
	var facing: Dictionary = DirectionUtil.resolve(_last_dir)
	sprite.flip_h = facing["facing_left"]
	sprite.play("%s_%s" % [state, facing["direction"]])
