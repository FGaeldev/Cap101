# scripts/util/DirectionUtil.gd
# Same 4-directional resolution Player already does inline. Static + stateless
# so both input-driven (Player) and cutscene-driven (NPC) actors stay on one
# naming convention -- no drift between the two anim sources.
class_name DirectionUtil
extends RefCounted

static func resolve(dir: Vector2) -> Dictionary:
	if dir == Vector2.ZERO:
		return {"direction": "down", "facing_left": false}
	if abs(dir.x) > abs(dir.y):
		return {"direction": "side", "facing_left": dir.x < 0}
	return {"direction": "up" if dir.y < 0 else "down", "facing_left": false}
