# scripts/autoload/BackButtonBridge.gd
# Android back button sends NOTIFICATION_WM_GO_BACK_REQUEST, not an input event.
# Bridge it into ui_cancel so every existing ui_cancel listener (BookUI, etc)
# just works — no per-screen back-button handling needed.
extends Node

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var ev := InputEventAction.new()
		ev.action = "ui_cancel"
		ev.pressed = true
		Input.parse_input_event(ev)
