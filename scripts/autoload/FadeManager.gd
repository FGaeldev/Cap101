# scripts/autoload/FadeManager.gd — same register pattern as DialogueUI
extends Node
var _fade: Node = null
func register_fade(node: Node) -> void: _fade = node
func fade_in(d: float = 0.6) -> void: if _fade: await _fade.fade_in(d)
func fade_out(d: float = 0.6) -> void: if _fade: await _fade.fade_out(d)
