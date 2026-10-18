# spawn_npc_action.gd -- instantiates an NPC scene into the running level at
# cutscene time, so one-shot cast members only exist while the cutscene needs them.
#
# JSON supports either explicit level-local coordinates ("at") or a Marker2D
# under the active level's NPCSpawn node ("at_marker"). Marker-based spawning
# keeps cutscene placement aligned with positions authored in the level scene.
class_name SpawnNpcCutsceneAction
extends RefCounted

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
	var marker_name: String = step.get("at_marker", "")

	if not marker_name.is_empty():
		# Markers live under NPCSpawn in the active level scene.
		var marker: Node2D = spawn_root.get_node_or_null("NPCSpawn/" + marker_name) as Node2D
		if marker == null:
			push_error("SpawnNpcCutsceneAction: marker 'NPCSpawn/%s' not found" % marker_name)
			return
		spawn_position = spawn_root.to_local(marker.global_position)
	else:
		var at: Array = step.get("at", [0, 0])
		if at.size() < 2:
			push_error("SpawnNpcCutsceneAction: 'at' must contain [x, y]")
			return
		spawn_position = Vector2(at[0], at[1])

	var npc: Node2D = (load(scene_path) as PackedScene).instantiate()
	# Set position before adding child to prevent a frame at the origin.
	npc.position = spawn_position
	spawn_root.add_child(npc)

	# Register immediately; some NPC scripts self-register via call_deferred.
	# Explicit registration ensures the next cutscene action can find this NPC.
	mgr.register_actor(step.get("actor", ""), npc)
