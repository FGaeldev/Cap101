# word_search_generator.gd -- hides words in a letter grid. No graphics;
# word_search_panel.gd draws the result.
class_name WordSearchGenerator
extends RefCounted

## Right, down, down-right, up-right. Words are written forwards only; the panel
## still accepts them being tapped from either end.
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
const GRID_ATTEMPTS: int = 80
const WORD_ATTEMPTS: int = 300

## First `count` entries that don't sit inside one another ("AMA" in "KAMA" would
## make one word findable inside the other), keeping the given priority order.
## entries: [{id, letters}].
static func pick_words(entries: Array, count: int) -> Array:
	var picked: Array = []
	for entry in entries:
		if picked.size() >= count:
			break
		var clash: bool = false
		for other in picked:
			if other["letters"].contains(entry["letters"]) or entry["letters"].contains(other["letters"]):
				clash = true
				break
		if not clash:
			picked.append(entry)
	return picked

## Returns {grid: rows of letters, placements: {id -> cells}}, or {} if the words
## did not fit. Longest words go first; they are the hardest to place.
static func generate(entries: Array, cols: int, rows: int) -> Dictionary:
	var order: Array = entries.duplicate()
	order.sort_custom(func(a, b): return a["letters"].length() > b["letters"].length())
	var filler: String = ""
	for entry in entries:
		filler += entry["letters"]

	for attempt in range(GRID_ATTEMPTS):
		var grid: Array = []
		for r in range(rows):
			var row: Array = []
			row.resize(cols)
			row.fill("")
			grid.append(row)
		var placements: Dictionary = {}
		var ok: bool = true
		for entry in order:
			var cells: Array = _place(grid, entry["letters"], cols, rows)
			if cells.is_empty():
				ok = false
				break
			placements[entry["id"]] = cells
		if not ok:
			continue
		# Filler drawn from the words' own letters so they don't stand out.
		for r in range(rows):
			for c in range(cols):
				if grid[r][c] == "":
					grid[r][c] = filler[randi() % filler.length()]
		return {"grid": grid, "placements": placements}
	return {}

## Writes `letters` at a random free spot (words may share matching letters).
## Returns its cells, or [] if no room was found.
static func _place(grid: Array, letters: String, cols: int, rows: int) -> Array:
	var length: int = letters.length()
	for attempt in range(WORD_ATTEMPTS):
		var dir: Vector2i = DIRECTIONS.pick_random()
		var c_hi: int = cols - length if dir.x == 1 else cols - 1
		var r_lo: int = length - 1 if dir.y == -1 else 0
		var r_hi: int = rows - length if dir.y == 1 else rows - 1
		if c_hi < 0 or r_hi < r_lo:
			continue
		var start := Vector2i(randi_range(0, c_hi), randi_range(r_lo, r_hi))
		var cells: Array = []
		for i in range(length):
			var cell: Vector2i = start + dir * i
			var existing: String = grid[cell.y][cell.x]
			if existing != "" and existing != letters[i]:
				cells.clear()
				break
			cells.append(cell)
		if cells.is_empty():
			continue
		for i in range(length):
			grid[cells[i].y][cells[i].x] = letters[i]
		return cells
	return []
