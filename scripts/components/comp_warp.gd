extends Area2D
class_name Comp_Warp
## Comp_Warp.gd
## Door/warp trigger component. Attach to an Area2D covering a doorway tile;
## on player entry, warps the persistent Player (see Game.gd) to
## target_scene, positioned at the Marker2D named target_spawn_id in that
## scene.
##
## Editor-settable per door instance (target_scene / target_spawn_id) — no
## central JSON registry, matches the "set it in editor, per-door" decision.
## Actual scene-swap work is delegated to MapManager.warp_to_scene(), which
## reuses the same abort/fade/save/load_level sequence as node-map region
## travel (MapManager.travel_to_region) — keeps CutsceneManager softlock
## safety (TDD §9 item 8) and save consistency identical across both warp
## paths instead of duplicating that sequence here.

## Absolute res:// path to the destination scene, e.g.
## "res://scenes/world/us_living.tscn".
@export var target_scene: String

## Name of the Marker2D in the destination scene to spawn the Player at.
## Falls back to "DefaultSpawn" if left blank or not found there.
@export var target_spawn_id: String = "DefaultSpawn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		MapManager.warp_to_scene(target_scene, target_spawn_id)
