# opening_hours.gd -- shops and public buildings close at night (v1.1.6).
# Their doors (comp_warp.gd) stay shut from CLOSE_HOUR until OPEN_HOUR, and a
# player still inside at closing time is told to head home and sleep (Game.gd).
# A door with ignore_closing_time set is the "unless stated otherwise".
# Story cutscenes load maps directly, so a story beat set at night still plays.
extends RefCounted

const OPEN_HOUR: float = 6.0
const CLOSE_HOUR: float = 21.0
const ESTABLISHMENTS: Array[String] = [
	"res://scenes/world/chapter2/cathedral_indoors.tscn",
	"res://scenes/world/chapter2/souvenir_shop.tscn",
	"res://scenes/world/market/market_indoors.tscn",
	"res://scenes/world/haboean/haboean_gallery.tscn",
	"res://scenes/world/haboean/haboean_cafe.tscn",
	"res://scenes/world/bakhawan/bakhawan_indoors.tscn",
]
const CLOSED_MESSAGE: String = "It's closed for the night. I should go home and get some sleep."
const CLOSING_MESSAGE: String = "They're closing up for the night. Time to head home and sleep."

static func is_establishment(scene_path: String) -> bool:
	return ESTABLISHMENTS.has(scene_path)

## True from CLOSE_HOUR until OPEN_HOUR.
static func is_closed_now() -> bool:
	var hour: float = DayNightManager.get_hour()
	return hour >= CLOSE_HOUR or hour < OPEN_HOUR
