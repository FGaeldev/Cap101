# interact_key.gd -- textures for the HUD interact button, drawn to match the
# D-pad keys (assets/ui/Dpad.png): the same 24x24 tan key with a dark base, and
# a pixel icon for what pressing it would do (the target's interact_label:
# Talk, Look, Pick up, Read, Sit, Sleep, Enter). Built once per icon from the
# D-pad's own palette, scaled 2x with nearest filtering by the button.
extends RefCounted

## Palette taken from Dpad.png.
const FACE := Color("bd9568")
const INK := Color("493333")
const SHADE := Color("7a5e52")
const BASE := Color("472e37")
const KEY := 24

## Icons, 14 px wide, '#' = ink. Centred on the key face.
const ICONS := {
	"talk": [
		"..##########..",
		".############.",
		"##############",
		"##..##..##..##",
		"##..##..##..##",
		"##############",
		".############.",
		"..##########..",
		"...###........",
		"...##.........",
		"...#..........",
	],
	"look": [
		"....######....",
		"..##########..",
		".####....####.",
		"####..##..####",
		"###..####..###",
		"###..####..###",
		"####..##..####",
		".####....####.",
		"..##########..",
		"....######....",
	],
	"pick up": [
		"......##......",
		"......##......",
		".....####.....",
		"....######....",
		"##############",
		"##############",
		"....######....",
		".....####.....",
		"......##......",
		"......##......",
	],
	"read": [
		".####....####.",
		"######..######",
		"#....#..#....#",
		"######..######",
		"#....#..#....#",
		"######..######",
		"##############",
		".#####..#####.",
	],
	"sit": [
		"..##..........",
		"..##..........",
		"..##..........",
		"..##..........",
		"..##..........",
		"..##########..",
		"..##########..",
		"..##......##..",
		"..##......##..",
		"..##......##..",
	],
	"sleep": [
		"######........",
		"....##........",
		"...##.........",
		"..##..........",
		".##.....#####.",
		"######.....##.",
		"..........##..",
		".........##...",
		"........#####.",
	],
	"enter": [
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..########.#..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"##############",
	],
}

static var _cache: Dictionary = {}

## Icon key for an interact_label ("Pick up" -> "pick up"); unknown labels talk.
static func icon_for(label: String) -> String:
	var key: String = label.strip_edges().to_lower()
	return key if ICONS.has(key) else "talk"

## The key texture for an icon; pressed = sunk a pixel and darker.
static func texture(icon: String, pressed: bool = false) -> Texture2D:
	var cache_key: String = "%s:%s" % [icon, pressed]
	if not _cache.has(cache_key):
		_cache[cache_key] = ImageTexture.create_from_image(_draw_key(icon, pressed))
	return _cache[cache_key]

static func _draw_key(icon: String, pressed: bool) -> Image:
	var img := Image.create(KEY, KEY, false, Image.FORMAT_RGBA8)
	var top: int = 1 if pressed else 0
	var face: Color = FACE.darkened(0.15) if pressed else FACE
	# Face rows top..21 with clipped top corners, then shade and base rows.
	for y in range(top, 22):
		for x in KEY:
			if y == top and (x == 0 or x == KEY - 1):
				continue
			img.set_pixel(x, y, face)
	for x in KEY:
		img.set_pixel(x, 21, SHADE if x > 0 and x < KEY - 1 else face)
		img.set_pixel(x, 22, BASE if x > 0 and x < KEY - 1 else SHADE)
	if not pressed:
		for x in range(1, KEY - 1):
			img.set_pixel(x, 23, BASE)
	# Icon, with the arrows' shade on its lower edge.
	var rows: Array = ICONS.get(icon, ICONS["talk"])
	var ox: int = (KEY - 14) / 2
	var oy: int = top + (21 - rows.size()) / 2
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != "#":
				continue
			img.set_pixel(ox + x, oy + y, INK)
			var below_empty: bool = y + 1 >= rows.size() or x >= rows[y + 1].length() or rows[y + 1][x] != "#"
			if below_empty and oy + y + 1 < 21:
				img.set_pixel(ox + x, oy + y + 1, SHADE)
	return img
