extends Node2D
## stub_area.gd
## Placeholder destination scene — Tier 0 "2-node proof" (GDD §2, §9 item 3;
## Roadmap Phase A). Only exists to prove the MapManager travel round-trip
## (village-side entry point still TODO, see MapManager.open_map()). Replace
## with a real area scene during Phase C area scale-up.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# TODO: BookUI, gameplay, and this scene all currently want ui_cancel
		# to mean something different — needs one arbiter, not solved here.
		MapManager.open_map()
