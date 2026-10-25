extends Node
## DayNightManager.gd
## Autoload. Runs the in-game clock (one 24h day = DAY_LENGTH_SEC real seconds)
## and tints the world for the time of day.
##
## Tint: a CanvasModulate that Game.gd creates and registers on boot
## (register_canvas_modulate). CanvasModulate only affects the canvas layer it
## lives on -- the world (levels, player, NPCs) -- so every CanvasLayer UI
## (Game's UILayer, BookUI, TutorialManager, ScreenFade) stays untinted.
##
## Light sources: scenes/entities/light_source.tscn (Comp_Light). They read
## light_factor (0 = full day, 1 = full night) and fade their energy with it.
##
## Date: GameState.date_unix (midnight of the in-game day) advances a day each
## time the clock wraps past 24:00; get_date() / format_clock() read it.
##
## Clock state lives in GameState.time_of_day (hours, 0..24) so it is saved
## and loaded with everything else. The clock only runs while a modulate is
## registered, i.e. while Game.tscn is running (not on the main menu), and
## stops whenever the scene tree is paused.
##
## Per-level strength: a level root may carry metadata "day_night_strength"
## (float, 0..1, default 1; Inspector > Add Metadata). 0 = never tinted (e.g. a
## lit interior), 0.5 = half-strength night. Game.load_level() applies it.

## Real seconds per in-game day. 960 s = 16 min, so one in-game hour = 40 s.
const DAY_LENGTH_SEC: float = 960.0

## [hour, Color] keyframes for the world tint, linearly blended, wrapping at 24.
const TINT_KEYS: Array = [
	[0.0, Color(0.32, 0.38, 0.62)],   # night (blue)
	[5.0, Color(0.32, 0.38, 0.62)],
	[6.5, Color(0.86, 0.74, 0.78)],   # dawn
	[8.0, Color(1.0, 1.0, 1.0)],      # day
	[17.0, Color(1.0, 1.0, 1.0)],
	[18.5, Color(0.95, 0.72, 0.62)],  # dusk
	[20.0, Color(0.32, 0.38, 0.62)],  # night
	[24.0, Color(0.32, 0.38, 0.62)],
]

## [hour, factor] keyframes for light sources: lamps come on through dusk and
## go out through dawn.
const LIGHT_KEYS: Array = [
	[0.0, 1.0],
	[5.5, 1.0],
	[7.0, 0.0],
	[17.5, 0.0],
	[19.5, 1.0],
	[24.0, 1.0],
]

## Emitted when the clock crosses into a new whole hour (0..23).
signal hour_changed(hour: int)
## Emitted when the clock passes midnight and the in-game date advances.
signal day_changed

const SECONDS_PER_DAY: int = 86400
const WEEKDAY_SHORT: Array[String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTH_NAMES: Array[String] = ["January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"]
## HUD clock granularity in in-game minutes (10 = ~6.7 real seconds per tick).
const CLOCK_STEP_MINUTES: int = 10

## 0 = full day, 1 = full night. Read by Comp_Light every frame.
var light_factor: float = 0.0

## Stops the clock (tint and lights hold) while true. For scripted scenes
## that need a fixed time of day.
var paused: bool = false

var _modulate: CanvasModulate = null
## Current level's "day_night_strength" (see header).
var _level_strength: float = 1.0

func _process(delta: float) -> void:
	if _modulate == null or not is_instance_valid(_modulate):
		return
	if not paused:
		var before: int = int(GameState.time_of_day)
		var raw: float = GameState.time_of_day + delta * 24.0 / DAY_LENGTH_SEC
		GameState.time_of_day = fposmod(raw, 24.0)
		if raw >= 24.0:
			GameState.date_unix += SECONDS_PER_DAY
			day_changed.emit()
		var after: int = int(GameState.time_of_day)
		if after != before:
			hour_changed.emit(after)
	_apply()

## Current in-game date: {year, month, day, weekday (0 = Sunday)}.
func get_date() -> Dictionary:
	return Time.get_date_dict_from_unix_time(GameState.date_unix)

## HUD clock text, e.g. "Mon 8:10 AM" (minutes floored to CLOCK_STEP_MINUTES).
func format_clock() -> String:
	var total_min: int = int(GameState.time_of_day * 60.0)
	total_min -= total_min % CLOCK_STEP_MINUTES
	var h24: int = total_min / 60
	var h12: int = h24 % 12
	if h12 == 0:
		h12 = 12
	var suffix: String = "AM" if h24 < 12 else "PM"
	return "%s %d:%02d %s" % [WEEKDAY_SHORT[get_date()["weekday"]], h12, total_min % 60, suffix]

## Called by Game.gd once on boot with the world's CanvasModulate.
func register_canvas_modulate(modulate: CanvasModulate) -> void:
	_modulate = modulate
	_apply()

## Called by Game.gd on every level swap with the level's tint strength.
func set_level_strength(strength: float) -> void:
	_level_strength = clampf(strength, 0.0, 1.0)
	_apply()

## Current time in hours (0..24, fractional).
func get_hour() -> float:
	return GameState.time_of_day

## Jumps the clock (e.g. dev menu, sleeping). Wraps into 0..24.
func set_hour(hour: float) -> void:
	GameState.time_of_day = fposmod(hour, 24.0)
	hour_changed.emit(int(GameState.time_of_day))
	_apply()

func is_night() -> bool:
	return light_factor >= 0.5

func _apply() -> void:
	var hour: float = GameState.time_of_day
	light_factor = _sample_float(LIGHT_KEYS, hour)
	if _modulate != null and is_instance_valid(_modulate):
		_modulate.color = Color.WHITE.lerp(_sample_color(TINT_KEYS, hour), _level_strength)

## Index of the keyframe at or before `hour`; keys must start at 0 and end at 24.
func _key_index(keys: Array, hour: float) -> int:
	for i in range(keys.size() - 1):
		if hour < keys[i + 1][0]:
			return i
	return keys.size() - 2

func _key_weight(keys: Array, i: int, hour: float) -> float:
	return inverse_lerp(keys[i][0], keys[i + 1][0], hour)

func _sample_color(keys: Array, hour: float) -> Color:
	var i: int = _key_index(keys, hour)
	return (keys[i][1] as Color).lerp(keys[i + 1][1], _key_weight(keys, i, hour))

func _sample_float(keys: Array, hour: float) -> float:
	var i: int = _key_index(keys, hour)
	return lerpf(keys[i][1], keys[i + 1][1], _key_weight(keys, i, hour))
