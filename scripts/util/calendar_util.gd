# calendar_util.gd — Gregorian calendar math + calendar event data.
# Preload it (no class_name, same as marker_util.gd):
#   const CalendarUtil := preload("res://scripts/util/calendar_util.gd")
#
# Events come from data/calendar_events.json:
#   { "events": [
#       { "id": "new_year", "title": "New Year's Day", "month": 1, "day": 1,
#         "description": "..." },                       # every year on Jan 1
#       { "id": "ati_atihan", "title": "Ati-Atihan Festival", "month": 1,
#         "nth": 3, "weekday": 0, "description": "..." },   # 3rd Sunday of Jan
#       { ..., "year": 2026 }                            # optional: that year only
#   ] }
# "weekday": 0 = Sunday .. 6 = Saturday. "nth": -1 = last such weekday.
extends RefCounted

const EVENTS_PATH := "res://data/calendar_events.json"

static var _events: Array = []
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("CalendarUtil: failed to open %s" % EVENTS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("events"):
		push_error("CalendarUtil: calendar_events.json malformed, expected {events: [...]}")
		return
	_events = parsed["events"]

static func days_in_month(year: int, month: int) -> int:
	const DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and is_leap_year(year):
		return 29
	return DAYS[month - 1]

static func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0

## 0 = Sunday .. 6 = Saturday.
static func weekday_of(year: int, month: int, day: int) -> int:
	var unix: int = Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0})
	return Time.get_date_dict_from_unix_time(unix)["weekday"]

## Day of month an event falls on in (year, month), or -1 if it doesn't.
static func event_day(event: Dictionary, year: int, month: int) -> int:
	if int(event.get("month", 0)) != month:
		return -1
	if event.has("year") and int(event["year"]) != year:
		return -1
	if event.has("day"):
		return int(event["day"])
	if event.has("nth") and event.has("weekday"):
		var nth: int = int(event["nth"])
		var weekday: int = int(event["weekday"])
		var count: int = days_in_month(year, month)
		if nth > 0:
			var first: int = 1 + posmod(weekday - weekday_of(year, month, 1), 7)
			var day: int = first + (nth - 1) * 7
			return day if day <= count else -1
		if nth == -1:
			return count - posmod(weekday_of(year, month, count) - weekday, 7)
	return -1

## [{day: int, event: Dictionary}] for (year, month), sorted by day.
static func events_in_month(year: int, month: int) -> Array:
	_ensure_loaded()
	var out: Array = []
	for event in _events:
		var day: int = event_day(event, year, month)
		if day > 0:
			out.append({"day": day, "event": event})
	out.sort_custom(func(a, b): return a["day"] < b["day"])
	return out
