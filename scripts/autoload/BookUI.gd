# BookUI.gd — autoload. Single entry point for relationship/dictionary/journal/settings.
extends CanvasLayer

const MARKER := preload("res://assets/ui/book/marker.png")
const MARKER_SLICE_MARGIN := 3   # placeholder — measure marker.png's actual corner px, replace this

const TAB_HOVER_SCALE := 1.15
const TAB_ANIM_TIME := 0.12

# tab_id -> { button: Button, title: String, is_unlocked: Callable }
var _tabs: Dictionary = {}
var _current_tab: String = ""

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Banner/Title
@onready var close_btn: Button = $Root/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_btn.pressed.connect(close)
	title_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	_register_tab("relationship", $Root/TabBar/TabRelationship, "RELATIONSHIP")
	_register_tab("dictionary", $Root/TabBar/TabDictionary, "DICTIONARY")
	_register_tab("bucket_list", $Root/TabBar/TabBucketList, "JOURNAL")
	_register_tab("settings", $Root/TabBar/TabSettings, "SETTINGS")

func _make_marker_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = MARKER
	sb.texture_margin_left = MARKER_SLICE_MARGIN
	sb.texture_margin_top = MARKER_SLICE_MARGIN
	sb.texture_margin_right = MARKER_SLICE_MARGIN
	sb.texture_margin_bottom = MARKER_SLICE_MARGIN
	# inset the icon so it doesn't touch/clip the marker's edge art
	sb.content_margin_left = 3
	sb.content_margin_top = 3
	sb.content_margin_right = 3
	sb.content_margin_bottom = 3
	return sb

func _register_tab(tab_id: String, button: Button, title: String) -> void:
	_tabs[tab_id] = {"button": button, "title": title, "is_unlocked": func(): return true}
	var style := _make_marker_style()
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	call_deferred("_set_pivot_bottom_left", button)
	button.mouse_entered.connect(func(): _animate_tab(tab_id, TAB_HOVER_SCALE))
	button.mouse_exited.connect(func(): _animate_tab(tab_id, TAB_HOVER_SCALE if tab_id == _current_tab else 1.0))
	button.pressed.connect(func(): switch_tab(tab_id))

func _set_pivot_bottom_left(button: Button) -> void:
	button.pivot_offset = Vector2(0, button.size.y)

func _animate_tab(tab_id: String, target_scale: float) -> void:
	var button: Button = _tabs[tab_id]["button"]
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(target_scale, target_scale), TAB_ANIM_TIME)

## Callable must return bool. Used to lock e.g. Dictionary before first word exposed.
func set_tab_lock_condition(tab_id: String, is_unlocked: Callable) -> void:
	if _tabs.has(tab_id):
		_tabs[tab_id]["is_unlocked"] = is_unlocked

func open(tab_id: String = "settings") -> void:
	visible = true
	get_tree().paused = true
	switch_tab(tab_id)

func close() -> void:
	visible = false
	get_tree().paused = false

func switch_tab(tab_id: String) -> void:
	if not _tabs.has(tab_id):
		push_error("BookUI: unknown tab '%s'" % tab_id)
		return
	var entry: Dictionary = _tabs[tab_id]
	if not entry["is_unlocked"].call():
		return  # locked chapter, ignore tap
	if not _current_tab.is_empty() and _current_tab != tab_id:
		_animate_tab(_current_tab, 1.0)
	_current_tab = tab_id
	_animate_tab(tab_id, TAB_HOVER_SCALE)
	title_label.text = entry["title"]
	# TODO: swap PageLeft/PageRight content for this tab — still unbuilt

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open("settings")
