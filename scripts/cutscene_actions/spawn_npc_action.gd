# spawn_npc_action.gd -- instantiates an NPC scene into the running level at
# cutscene time, so one-shot cast members only exist while the cutscene needs them.
#
# JSON supports either explicit level-local coordinates ("at") or a Marker2D
# anywhere under the active level ("at_marker", e.g. "S3/Susan"). Marker-based spawning
# keeps cutscene placement aligned with positions authored in the level scene.
class_name SpawnNpcCutsceneAction
extends RefCounted

const MarkerUtil := preload("res://scripts/util/marker_util.gd")

func action_type() -> String:
	return "spawn_npc"

func execute(step: Dictionary, mgr: Node) -> void:
	var scene_path: String = step.get("scene", "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_error("SpawnNpcCutsceneAction: missing/invalid 'scene' (%s)" % scene_path)
		return

	# Player is reparented into the active level by Game.load_level(), so its
	# parent is the correct (y-sorted) spawn root without hardcoding a path.
	var player: Node = mgr.get_actor("player")
	if player == null or player.get_parent() == null:
		push_error("SpawnNpcCutsceneAction: no player/level to parent '%s' under" % scene_path)
		return

	var spawn_root: Node = player.get_parent()
	var spawn_position: Vector2
	# "at_marker" (or a marker name in "at") is looked up anywhere under the
	# level, e.g. "S3/Susan" -> SceneMarkers/S3/Susan. "at": [x, y] stays
	# level-local, as before.
	var where: Variant = step.get("at_marker", step.get("at", [0, 0]))
	if where is String:
		var marker := MarkerUtil.find(spawn_root, where)
		if marker == null:
			push_error("SpawnNpcCutsceneAction: marker '%s' not found in '%s'" % [where, spawn_root.name])
			return
		spawn_position = spawn_root.to_local(marker.global_position)
	elif where is Array and where.size() >= 2:
		spawn_position = Vector2(where[0], where[1])
	else:
		push_error("SpawnNpcCutsceneAction: 'at' must be [x, y] or a marker name")
		return

	var npc: Node2D = (load(scene_path) as PackedScene).instantiate()
	# Set position before adding child to prevent a frame at the origin.
	npc.position = spawn_position
	spawn_root.add_child(npc)

	# Register immediately; some NPC scripts self-register via call_deferred.
	# Explicit registration ensures the next cutscene action can find this NPC.
	mgr.register_actor(step.get("actor", ""), npc)
