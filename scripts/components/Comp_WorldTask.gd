# Comp_WorldTask.gd
# Attach as sibling to Comp_Interactable on giver/target objects.
# Popup is per-instance opt-in — set fields in Inspector, no JSON needed.
extends Node
class_name WorldTaskComponent

@export_enum("giver", "target") var mode: String
@export var task_id: String
@export var required_step: int = 0

# MODULAR POPUP — editor-settable, empty text = no popup for this instance
@export var show_popup: bool = false
@export var inline_popup_speaker: String = ""
@export_multiline var inline_popup_text: String = ""

@onready var interactable: InteractableComponent = $"../InteractableComponent"


func _ready() -> void:
	# register on ready, call through autoload — matches TDD §2 pattern
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_interactor: Node) -> void:
	match mode:
		"giver":
			TaskManager.start_task(task_id)
		"target":
			if TaskManager.get_current_step(task_id) == required_step:
				TaskManager.advance_task_step(task_id)

	# fire popup AFTER task logic, only if this instance opts in
	if show_popup and inline_popup_text != "":
		_show_popup()


func _show_popup() -> void:
	# themed panel — uses same nine-slice chrome as dialogue box, not default AcceptDialog
	var popup := PopupPanel.new()
	popup.add_theme_stylebox_override("panel", UIThemeApplier.make_dialogue_style())

	var vbox := VBoxContainer.new()
	popup.add_child(vbox)
	

	if inline_popup_speaker != "":
		var speaker_label := Label.new()
		speaker_label.text = inline_popup_speaker
		speaker_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_L)
		speaker_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_EMPHASIS)
		vbox.add_child(speaker_label)

	var text_label := Label.new()
	text_label.text = inline_popup_text
	text_label.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_M)
	text_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text_label)
	
	var close_button := Button.new()
	close_button.text = "Close"
	UIThemeApplier.apply_button_theme(close_button, "confirm")
	close_button.add_theme_font_size_override("font_size", UIThemeApplier.FONT_SIZE_S)
	vbox.add_child(close_button)

	get_tree().root.add_child(popup)
	popup.popup_centered()

	# close button + click-outside both dismiss — queue_free either way, no dupes
	close_button.pressed.connect(popup.queue_free)
	popup.popup_hide.connect(popup.queue_free)
