# stall_vendors.gd -- stands the market's NPCs at their markers. NPCs go away with
# the level. Nobody is placed anywhere but a marker:
#   - Each Marker2D under markers_path gets a background NPC, facing the shop floor,
#     that doesn't walk or talk. Scenes are dealt out in shuffled rounds, so
#     neighbouring stalls rarely match.
#   - named_marker_path gets named_scene, a character with their own marker.
extends Node2D

@export var markers_path: NodePath = ^"../SceneMarkers/Vendors"
@export var npc_scenes: Array[PackedScene] = []
@export var named_marker_path: NodePath = ^"../SceneMarkers/S2/Pedring"
@export var named_scene: PackedScene = null

func _ready() -> void:
	var deck: Array[PackedScene] = []
	for marker: Node2D in get_node(markers_path).get_children():
		if deck.is_empty():
			deck = npc_scenes.duplicate()
			deck.shuffle()
		_place(deck.pop_back(), marker)
	if named_scene != null:
		_place(named_scene, get_node(named_marker_path))

func _place(scene: PackedScene, marker: Node2D) -> void:
	var npc: Node2D = scene.instantiate()
	add_child(npc)
	npc.global_position = marker.global_position
