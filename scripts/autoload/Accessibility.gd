# Accessibility.gd -- the player's accessibility settings, saved in
# user://settings.cfg (a setting of the device, not of a save file; see UIScale).
#
# Color blind mode never relies on hue alone: Akeanon words turn blue (they're
# always underlined), color quizzes name each color, and quiz feedback uses a
# blue/orange pair and says which answer was right.
extends Node

signal changed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "accessibility"
const KEY_COLOR_BLIND := "color_blind"

## Akeanon words in dialogue. Both read clearly on the parchment dialogue box.
const AKEANON_COLOR := Color("b0123b")
const AKEANON_COLOR_BLIND := Color("0b4fa8")
## Okabe-Ito pair, distinguishable with all common color vision deficiencies.
const SUCCESS_COLOR_BLIND := Color("0072b2")
const ERROR_COLOR_BLIND := Color("d55e00")

var color_blind: bool = false

## On-screen movement control: the analog joystick or a 4-way D-pad (dpad.gd).
## Both press the ui_* actions; the HUD shows whichever is chosen.
const KEY_MOVEMENT := "movement_controls"
const MOVEMENT_JOYSTICK := "joystick"
const MOVEMENT_DPAD := "dpad"
const MOVEMENT_OPTIONS := {MOVEMENT_JOYSTICK: "Joystick", MOVEMENT_DPAD: "D-pad"}
var movement_controls: String = MOVEMENT_JOYSTICK


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		color_blind = bool(config.get_value(SECTION, KEY_COLOR_BLIND, false))
		var movement := str(config.get_value(SECTION, KEY_MOVEMENT, MOVEMENT_JOYSTICK))
		movement_controls = movement if MOVEMENT_OPTIONS.has(movement) else MOVEMENT_JOYSTICK


func set_movement_controls(kind: String) -> void:
	if kind == movement_controls or not MOVEMENT_OPTIONS.has(kind):
		return
	movement_controls = kind
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keeps other keys; a missing file is fine
	config.set_value(SECTION, KEY_MOVEMENT, movement_controls)
	config.save(SETTINGS_PATH)
	changed.emit()


func uses_dpad() -> bool:
	return movement_controls == MOVEMENT_DPAD


func set_color_blind(enabled: bool) -> void:
	if enabled == color_blind:
		return
	color_blind = enabled
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keeps other keys; a missing file is fine
	config.set_value(SECTION, KEY_COLOR_BLIND, color_blind)
	config.save(SETTINGS_PATH)
	changed.emit()


func akeanon_color() -> Color:
	return AKEANON_COLOR_BLIND if color_blind else AKEANON_COLOR


func success_color() -> Color:
	return SUCCESS_COLOR_BLIND if color_blind else UIThemeApplier.COLOR_SUCCESS


func error_color() -> Color:
	return ERROR_COLOR_BLIND if color_blind else UIThemeApplier.COLOR_ERROR
