# camera_action.gd — cutscene camera control: pan to point/actor, zoom, or release
# back to following player. Camera2D must have top_level=true (see Player.tscn)
# so its global_position moves independent of the Player parent node.
class_name CameraCutsceneAction
extends RefCounted

func action_type() -> String:
	return "camera"

# step examples:
# {"type":"camera", "mode":"focus", "to":[140,90], "duration":1.0 }
# {"type":"camera", "mode":"focus_actor", "actor":"rose", "duration":1.0 }
# {"type":"camera", "mode":"zoom", "to":[1.8,1.8], "duration":0.5 }
# {"type":"camera", "mode":"release", "duration":0.6 }   -- back to following player
# {"type":"camera", "mode":"follow", "actor":"lola_susan"}
func execute(step: Dictionary, mgr: Node) -> void:
	var cam: Camera2D = mgr.get_actor("camera")
	if cam == null:
		return
	var mode: String = step.get("mode", "focus")
	var duration: float = step.get("duration", 1.0)

	match mode:
		"focus":
			var to: Array = step.get("to", [0, 0])
			cam.top_level = true
			var tween := cam.create_tween()
			tween.tween_property(cam, "global_position", Vector2(to[0], to[1]), duration)
			await tween.finished
		"focus_actor":
			var target: Node2D = mgr.get_actor(step.get("actor", ""))
			if target == null:
				return
			cam.top_level = true
			var tween := cam.create_tween()
			tween.tween_property(cam, "global_position", target.global_position, duration)
			await tween.finished
		"follow":
			var target: Node2D = mgr.get_actor(step.get("actor", ""))
			if target == null:
				return
			mgr.camera_follow(target)
			# no await -- sequence continues immediately, camera keeps tracking in background
		"zoom":
			var to_zoom: Array = step.get("to", [1.5, 1.5])
			var tween := cam.create_tween()
			tween.tween_property(cam, "zoom", Vector2(to_zoom[0], to_zoom[1]), duration)
			await tween.finished
		"release":
			mgr.camera_release()
			await mgr.get_tree().create_timer(duration, false).timeout
			var cam2: Camera2D = mgr.get_actor("camera")
			var player: Node2D = mgr.get_actor("player")
			if cam2 and player:
				cam2.global_position = player.global_position  # force exact match
				cam2.top_level = false
				cam2.position = Vector2.ZERO
