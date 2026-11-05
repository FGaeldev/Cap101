# UIScale.gd -- the player's UI size setting, saved in user://settings.cfg (a
# setting of the device, not of a save file).
#
# NATIVE_VALUE is the option that shows the UI at its authored size (the 640x360
# layout). Book and dialogue need nearly all of that layout, so it sits near the
# top of the range: 2.5 is the largest size at which they still fit.
#
# Scales every Control through Window.content_scale_factor, so anchors, popups
# and input mapping keep working. That factor scales the 2D world too, so Game.gd
# divides the camera zoom by the same amount: the world stays the same size on
# screen. Code that sets the camera zoom has to divide by `factor` as well.
extends Node

## Emits factors, not option values.
signal changed(previous: float, current: float)

const OPTIONS: Array[float] = [1.0, 1.5, 2.0, 2.5]
const NATIVE_VALUE: float = 2.0
const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "ui"
const KEY := "scale"

## The chosen option.
var value: float = NATIVE_VALUE
## What it multiplies the authored layout by.
var factor: float:
	get:
		return value / NATIVE_VALUE

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: float = config.get_value(SECTION, KEY, NATIVE_VALUE)
		if OPTIONS.has(saved):
			value = saved
	get_window().content_scale_factor = factor

func set_value(new_value: float) -> void:
	if new_value == value or not OPTIONS.has(new_value):
		return
	var previous: float = factor
	value = new_value
	get_window().content_scale_factor = factor
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)  # keeps other keys; a missing file is fine
	config.set_value(SECTION, KEY, value)
	config.save(SETTINGS_PATH)
	changed.emit(previous, factor)
