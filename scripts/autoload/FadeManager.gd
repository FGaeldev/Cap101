# scripts/autoload/FadeManager.gd — same register pattern as DialogueUI
extends Node
var _fade: Node = null
func register_fade(node: Node) -> void: _fade = node
func fade_in(d: float = 0.6) -> void: if _fade: await _fade.fade_in(d)
func fade_out(d: float = 0.6) -> void: if _fade: await _fade.fade_out(d)
## True while the screen is (mostly) covered by the fade, e.g. mid-warp.
func is_black() -> bool: return _fade != null and _fade.rect.modulate.a > 0.5
## True while the fade covers the screen at all (fading out, black, fading in).
func is_fading() -> bool: return _fade != null and is_instance_valid(_fade) and _fade.rect.modulate.a > 0.01
