## Generic reusable yes/no confirmation dialog.
## Caller sets message via open(text), connects to "confirmed"/"canceled" signals.
## Does NOT handle scene changes or CutsceneManager.abort() itself —
## caller's responsibility (keeps this component dumb/reusable per TDD §3 pattern).
extends Control
class_name ConfirmPopup

signal confirmed
signal canceled

@onready var panel: PanelContainer = $PanelContainer
@onready var message_label: Label = $PanelContainer/VBoxContainer/Label
@onready var confirm_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/CancelButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must respond while tree paused (BookUI use case)
	hide()
	
	message_label.add_theme_color_override("font_color", UIThemeApplier.TEXT_DEFAULT)
	
	panel.add_theme_stylebox_override("panel", UIThemeApplier.make_panel_style())
	UIThemeApplier.apply_button_theme(confirm_button, "confirm")
	UIThemeApplier.apply_button_theme(cancel_button, "danger")

	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

## Call this to show the popup with custom message text.
func open(text: String) -> void:
	message_label.text = text
	show()

func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()

func _on_cancel_pressed() -> void:
	hide()
	canceled.emit()
