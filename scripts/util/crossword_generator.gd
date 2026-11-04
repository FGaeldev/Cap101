# crossword_generator.gd -- builds a crossword layout from a priority-ordered
# word list. No graphics; crossword_panel.gd draws the result.
#
# Greedy: words are tried in the given order, each placed where it crosses the
# most letters and grows the grid least. Words that don't fit yet are retried
# after later words add new letters to cross, so earlier (higher priority) words
# always get first pick of the grid.
class_name CrosswordGenerator
extends RefCounted

const ACROSS := Vector2i(1, 0)
const DOWN := Vector2i(0, 1)

## Score per crossing vs per cell of grid growth: prefers interlocked, compact grids.
const CROSSING_SCORE: int = 10
const ILLEGAL: int = -9999

## entries: [{id, letters}], highest priority first.
## Returns {cols, rows, placements: [{id, letters, cell, dir, number}]}, or {}
## if nothing could be placed.
static func generate(entries: Array, max_cols: int, max_rows: int, target_words: int) -> Dictionary:
	var state := {"cells": {}, "dirs": {}, "placements": []}
	var remaining: Array = entries.duplicate()
	var placed_any: bool = true
	while placed_any and state["placements"].size() < target_words:
		placed_any = false
		for entry in remaining.duplicate():
			if state["placements"].size() >= target_words:
				break
			var fit: Dictionary = _best_fit(state, entry["letters"], max_cols, max_rows)
			if fit.is_empty():
				continue
			_place(state, entry, fit)
			remaining.erase(entry)
			placed_any = true
	return _finish(state)

## Best legal spot for `letters`: the first word goes at the origin, every later
## one must cross an existing letter.
static func _best_fit(state: Dictionary, letters: String, max_cols: int, max_rows: int) -> Dictionary:
	var cells: Dictionary = state["cells"]
	if cells.is_empty():
		return {"cell": Vector2i.ZERO, "dir": ACROSS} if letters.length() <= max_cols else {}
	var best: Dictionary = {}
	var best_score: int = ILLEGAL
	for crossed in cells.keys():
		for i in range(letters.length()):
			if cells[crossed] != letters[i]:
				continue
			for dir in [ACROSS, DOWN]:
				var start: Vector2i = crossed - dir * i
				var score: int = _score(state, letters, start, dir, max_cols, max_rows)
				if score > best_score:
					best_score = score
					best = {"cell": start, "dir": dir}
	return best

## Score of a placement, or ILLEGAL. Legal means: in bounds, no letter clashes, no
## running along an existing word, nothing touching end-on or side-on except at
## real crossings.
static func _score(state: Dictionary, letters: String, start: Vector2i, dir: Vector2i, max_cols: int, max_rows: int) -> int:
	var cells: Dictionary = state["cells"]
	var dirs: Dictionary = state["dirs"]
	var side := Vector2i(dir.y, dir.x)
	var last: Vector2i = start + dir * (letters.length() - 1)
	if cells.has(start - dir) or cells.has(last + dir):
		return ILLEGAL
	var crossings: int = 0
	for i in range(letters.length()):
		var cell: Vector2i = start + dir * i
		if cells.has(cell):
			if cells[cell] != letters[i] or dirs[cell].has(dir):
				return ILLEGAL
			crossings += 1
		elif cells.has(cell + side) or cells.has(cell - side):
			return ILLEGAL
	if crossings == 0:
		return ILLEGAL
	var bounds: Rect2i = _bounds(cells).expand(start).expand(last)
	# Rect2i.expand treats its end as exclusive of the last cell; +1 counts it.
	var width: int = bounds.size.x + 1
	var height: int = bounds.size.y + 1
	if width > max_cols or height > max_rows:
		return ILLEGAL
	return crossings * CROSSING_SCORE - width - height

static func _bounds(cells: Dictionary) -> Rect2i:
	var bounds := Rect2i(cells.keys()[0], Vector2i.ZERO)
	for cell in cells.keys():
		bounds = bounds.expand(cell)
	return bounds

static func _place(state: Dictionary, entry: Dictionary, fit: Dictionary) -> void:
	var letters: String = entry["letters"]
	for i in range(letters.length()):
		var cell: Vector2i = fit["cell"] + fit["dir"] * i
		state["cells"][cell] = letters[i]
		if not state["dirs"].has(cell):
			state["dirs"][cell] = []
		state["dirs"][cell].append(fit["dir"])
	state["placements"].append({"id": entry["id"], "letters": letters, "cell": fit["cell"], "dir": fit["dir"]})

## Shifts the layout to start at (0, 0) and numbers word starts in reading order
## (a cell starting both an across and a down word shares one number).
static func _finish(state: Dictionary) -> Dictionary:
	var placements: Array = state["placements"]
	if placements.is_empty():
		return {}
	var bounds: Rect2i = _bounds(state["cells"])
	var starts: Array = []
	for p in placements:
		p["cell"] -= bounds.position
		if not starts.has(p["cell"]):
			starts.append(p["cell"])
	starts.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for p in placements:
		p["number"] = starts.find(p["cell"]) + 1
	return {"cols": bounds.size.x + 1, "rows": bounds.size.y + 1, "placements": placements}
