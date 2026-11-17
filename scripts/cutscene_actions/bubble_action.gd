# bubble_action.gd -- a picture bubble over an actor for a silent beat.
#
#   {"type": "bubble", "actor": "Lola Jonabel", "icon": "bell", "seconds": 2}
#
# Waits while the bubble is up, then removes it. Icons: data/bubble_icons.json.
class_name BubbleCutsceneAction
extends RefCounted

func action_type() -> String:
	return "bubble"

func execute(step: Dictionary, _mgr: Node) -> void:
	await PictureBubbles.pop(str(step.get("actor", "")), str(step.get("icon", "")), float(step.get("seconds", 1.5)))
