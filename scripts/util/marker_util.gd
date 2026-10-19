# marker_util.gd — finds Marker2D positions authored in level scenes.
# Preload it (no class_name, so it resolves without the editor's class cache):
#   const MarkerUtil := preload("res://scripts/util/marker_util.gd")
#
# Levels group markers under organizing nodes (Spawns/, SceneMarkers/S3/, ...),
# so lookups accept either a node path relative to the level root
# ("SceneMarkers/S3/Susan", "S3/Susan") or a bare marker name ("Stairs").
extends RefCounted

## Marker for `marker_ref` under `level`, or null. Tries, in order:
##   1. the exact node path from the level root,
##   2. a descendant whose path ENDS with marker_ref ("S3/Susan" matches
##      "SceneMarkers/S3/Susan"),
## so short refs keep working when markers get regrouped. First match in tree
## order wins; only Marker2D nodes count for the fuzzy step.
static func find(level: Node, marker_ref: String) -> Node2D:
	if level == null or marker_ref.is_empty():
		return null
	var direct := level.get_node_or_null(marker_ref) as Node2D
	if direct != null:
		return direct
	var leaf := marker_ref.get_file()
	var suffix := "/" + marker_ref
	for node in level.find_children(leaf, "Marker2D", true, false):
		var rel := "/" + str(level.get_path_to(node))
		if rel.ends_with(suffix):
			return node as Node2D
	return null

## Resolves a JSON position value to a global position. Accepts a marker ref
## (String) or a two-number [x, y] array in level space. Returns null (and
## logs `context`) when it can't be resolved, so callers can bail out.
static func resolve(level: Node, value: Variant, context: String) -> Variant:
	if value is String:
		var marker := find(level, value)
		if marker == null:
			push_error("%s: marker '%s' not found in '%s'" % [context, value, level.name if level else "<no level>"])
			return null
		return marker.global_position
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	push_error("%s: expected a marker name or [x, y], got %s" % [context, value])
	return null
