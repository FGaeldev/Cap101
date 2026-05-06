# UIThemeApplier.gd
# Applies Stardew-style tropical theme to all UI nodes at runtime
extends Node

# --- Palette ---
const COL_PANEL_BG     = Color("1a1a2e")   # deep navy bg
const COL_PANEL_BORDER = Color("5c3a1e")   # warm brown border (Stardew wood)
const COL_INNER_BG     = Color("fdf6e3")   # warm cream interior
const COL_TEXT_DARK    = Color("2c1810")   # dark brown text
const COL_TEXT_LIGHT   = Color("fdf6e3")   # cream text
const COL_ACCENT       = Color("4a7c59")   # tropical green accent
const COL_ACCENT_HOVER = Color("6aad7a")   # lighter green hover
const COL_ACCENT_PRESS = Color("2d5e3a")   # dark green press
const COL_GOLD         = Color("e8b84b")   # warm gold highlight
const COL_SEPARATOR    = Color("c8a96e")   # tan separator

func make_panel_style(bg: Color = COL_INNER_BG, border: Color = COL_PANEL_BORDER, border_w: int = 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func make_button_style(bg: Color, border: Color = COL_PANEL_BORDER) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	s.set_content_margin(SIDE_LEFT, 12)
	s.set_content_margin(SIDE_RIGHT, 12)
	s.set_content_margin(SIDE_TOP, 6)
	s.set_content_margin(SIDE_BOTTOM, 6)
	return s
