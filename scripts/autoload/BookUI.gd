# BookUI.gd — autoload. Single entry point for pause/settings/dictionary/bucket-list.
extends CanvasLayer

const SLOT_FRAME := preload("res://assets/ui/book/slot_frame.png")
const SLOT_FRAME_SELECTED := preload("res://assets/ui/book/slot_frame_selected.png")
const SLOT_FRAME_UNAVAILABLE := preload("res://assets/ui/book/slot_frame_unavailable.png")

# tab_id -> { button: TextureButton, page: Control, is_unlocked: Callable }
var _tabs: Dictionary = {}
var _current_tab: String = ""

@onready var root: Control = $Root
@onready var pages: Control = $Root/Pages
@onready var bookmarks: VBoxContainer = $Root/Bookmarks

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_register_tab("settings", $Root/Bookmarks/TabSettings, $Root/Pages/SettingsPage)
	_register_tab("dictionary", $Root/Bookmarks/TabDictionary, $Root/Pages/DictionaryPage)
	_register_tab("bucket_list", $Root/Bookmarks/TabBucketList, $Root/Pages/BucketListPage)

func _make_panel_style(tex: Texture2D, margin: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	return sb

func _register_tab(tab_id: String, button: Button, page: Control) -> void:
	_tabs[tab_id] = {"button": button, "page": page, "is_unlocked": func(): return true}
	button.add_theme_stylebox_override("normal", _make_panel_style(SLOT_FRAME, 3))
	button.add_theme_stylebox_override("pressed", _make_panel_style(SLOT_FRAME, 3))
	button.add_theme_stylebox_override("hover", _make_panel_style(SLOT_FRAME, 3))
	button.pressed.connect(func(): switch_tab(tab_id))
	page.visible = false

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
	if not _current_tab.is_empty():
		_tabs[_current_tab]["page"].visible = false
		_tabs[_current_tab]["button"].add_theme_stylebox_override("normal", _make_panel_style(SLOT_FRAME, 3))
	_current_tab = tab_id
	entry["page"].visible = true
	entry["button"].add_theme_stylebox_override("hover", _make_panel_style(SLOT_FRAME_SELECTED, 3))
	entry["button"].add_theme_stylebox_override("normal", _make_panel_style(SLOT_FRAME_SELECTED, 3))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			close()
		else:
			open("settings")
			
