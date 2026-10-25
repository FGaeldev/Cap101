extends PointLight2D
class_name Comp_Light
## comp_light.gd
## Light source for the day/night cycle (DayNightManager). Root script of
## scenes/entities/light_source.tscn: instance it in a level, place it on a
## lamp/window/torch, and tune color / texture_scale (radius) in the Inspector.
##
## Energy follows DayNightManager.light_factor, so lamps are off by day and
## fade in through dusk. PointLight2D's default Add blend brightens whatever
## the night CanvasModulate darkened, which is what makes it read as light.

## Energy at full night.
@export_range(0.0, 4.0, 0.05) var night_energy: float = 1.0

## Ignore the clock and stay lit (e.g. an indoor lamp in a level whose
## day_night_strength is below 1). Still uses night_energy.
@export var always_on: bool = false

## Random energy wobble, as a fraction of the current energy (0 = steady;
## ~0.1 suits a candle or torch).
@export_range(0.0, 0.5, 0.01) var flicker: float = 0.0

## Wobble speed for flicker.
@export_range(0.5, 20.0, 0.5) var flicker_speed: float = 8.0

var _noise := FastNoiseLite.new()
var _t: float = 0.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0
	_update(0.0)

func _process(delta: float) -> void:
	_update(delta)

func _update(delta: float) -> void:
	var factor: float = 1.0 if always_on else DayNightManager.light_factor
	var target: float = night_energy * factor
	if flicker > 0.0 and target > 0.0:
		_t += delta * flicker_speed
		target *= 1.0 + _noise.get_noise_1d(_t) * flicker
	energy = target
	# Fully off by day: skip the light pass entirely.
	enabled = target > 0.001
