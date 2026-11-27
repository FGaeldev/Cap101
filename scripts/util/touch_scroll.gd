# touch_scroll.gd — lets a finger drag any scroll list by its body, not only
# by its thin scrollbar (Android).
#
# ScrollContainer drags on touch, but only events that reach it: rows built
# from Buttons, PanelContainers and RichTextLabels stop the touch first. So
# every such control that enters the tree inside a ScrollContainer is switched
# to MOUSE_FILTER_PASS (it still gets taps; the drag reaches the list too),
# and each list gets a dead zone so a tap that wobbles stays a tap. Controls
# that drag on their own (sliders, text fields, scrollbars) are left alone.
# UIThemeApplier._ready() calls watch() once.

## Pixels a touch has to move before the list scrolls instead of tapping.
const DEADZONE := 12

static func watch(tree: SceneTree) -> void:
	tree.node_added.connect(_on_node_added)

static func _on_node_added(node: Node) -> void:
	if node is ScrollContainer:
		if node.scroll_deadzone == 0:
			node.scroll_deadzone = DEADZONE
		return
	if not node is Control or node.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if node is Range or node is LineEdit or node is TextEdit:
		return
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		parent = parent.get_parent()
