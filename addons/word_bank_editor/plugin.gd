@tool
extends EditorPlugin
## Adds the Word Bank workspace to the editor's top bar, and connects it to
## Godot's undo history, save and close handling.

const Screen := preload("word_bank_screen.gd")

var _screen: Control


func _enter_tree() -> void:
	_screen = Screen.new()
	_screen.undo = get_undo_redo()
	EditorInterface.get_editor_main_screen().add_child(_screen)
	_make_visible(false)


func _exit_tree() -> void:
	if _screen != null:
		_screen.queue_free()
		_screen = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _screen == null:
		return
	_screen.visible = visible
	if visible:
		_screen.activate()


func _get_plugin_name() -> String:
	return "Word Bank"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("Translation", "EditorIcons")


## Runs on Save All and before the game launches, so F5 uses the latest words.
func _save_external_data() -> void:
	if _screen != null:
		_screen.save_now()


func _get_unsaved_status(for_scene: String) -> String:
	if for_scene.is_empty() and _screen != null and _screen.has_unsaved_changes():
		return "Save changes to the Word Bank before closing?"
	return ""
