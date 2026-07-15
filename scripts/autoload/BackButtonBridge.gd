# scripts/autoload/BackButtonBridge.gd
# Android back button sends NOTIFICATION_WM_GO_BACK_REQUEST, not an input event.
# Bridge it into ui_cancel so every existing ui_cancel listener (PauseMenu, etc)
# just works — no per-screen back-button handling needed.
extends Node

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Input.action_press("ui_cancel")
		Input.action_release("ui_cancel")
