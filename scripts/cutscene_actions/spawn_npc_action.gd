# spawn_npc_action.gd -- instantiates an NPC scene into the running level at
# cutscene time, so one-shot cast members (e.g. Lola/Papa arriving at the
# airport) only exist while the cutscene needs them, instead of being baked
# into the level .tscn where they would persist on every revisit.
#
# The spawned NPC registers itself with CutsceneManager in its own _ready()
# (via its exported actor_id), so later move_npc / set_visible / despawn_npc
# steps can address it by id. The NPC scene's actor_id MUST equal "actor".
#
# JSON usage:
#   {"type":"spawn_npc", "actor":"Lola Jonabel",
#    "scene":"res://scenes/entities/npc_LolaJonabel.tscn", "at":[-64,48]}
#
# "at" is in level-local coordinates (level roots sit at the origin, so this
# equals global position). Position is set BEFORE add_child so the NPC never
# renders for a frame at (0,0).
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

	var at: Array = step.get("at", [0, 0])
	var npc: Node2D = (load(scene_path) as PackedScene).instantiate()
	npc.position = Vector2(at[0], at[1])
	player.get_parent().add_child(npc)
	# Register NOW, by the step's actor id. Some NPC scripts (papaJobert.gd)
	# self-register via call_deferred, i.e. one frame too late -- the very next
	# move_npc/despawn_npc step would find no actor and silently do nothing.
	# Re-registering the same node is harmless.
	mgr.register_actor(step.get("actor", ""), npc)
