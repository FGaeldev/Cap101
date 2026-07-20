extends Node2D
## stub_area.gd
## Placeholder destination scene — Tier 0 "2-node proof" (GDD §2, §9 item 3;
## Roadmap Phase A). Only exists to prove the MapManager travel round-trip
## (village-side entry point still TODO, see MapManager.open_map()). Replace
## with a real area scene during Phase C area scale-up.

## NOTE: deliberately not wired to ui_cancel. BookUI._unhandled_input reacts
## to ui_cancel globally (opens Settings whenever BookUI is closed, no scene
## guard) — hooking Back here raced it: pressing Back returned to the map
## AND popped BookUI open on top of it. Using an explicit button instead
## until back-button semantics get one arbiter across BookUI/map/gameplay
## (still an open decision, not solved here).
func _on_return_to_map_pressed() -> void:
	MapManager.open_map()
