# scripts/cutscene_actions/load_scene_action.gd
# Cutscene action: swap the running level. Routes through Game.gd::load_level()
# (swaps LevelContainer's child), NOT get_tree().change_scene_to_file() -- the
# latter replaces Game.tscn itself and destroys the persistent UILayer
# (HUD/ScreenFade/DialogueRoot/WordReveal/QuestCompletePopup/PuzzlePanel).
# Same reasoning as MapManager.travel_to_region(), see that function's comment.
#
# JSON usage:
#   {"type": "load_scene", "scene_path": "res://scenes/world/scene_2.tscn"}
#
# Caller is responsible for fading out beforehand (e.g. a preceding
# {"type": "fade", "direction": "out"} step) -- this action does not fade.
class_name LoadSceneCutsceneAction
extends RefCounted

func action_type() -> String: return "load_scene"

func execute(step: Dictionary, mgr: Node) -> void:
	var scene_path: String = step.get("scene_path", "")
	if scene_path.is_empty():
		push_error("LoadSceneCutsceneAction: missing 'scene_path'")
		return

	var game := mgr.get_tree().current_scene
	if game == null or not game.has_method("load_level"):
		push_error("LoadSceneCutsceneAction: current_scene has no load_level() -- not running inside Game.tscn")
		return

	GameState.current_level_path = scene_path
	GameState.save_game()
	game.load_level(scene_path)
