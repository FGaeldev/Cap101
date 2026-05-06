# WordBank.gd — Loads and queries Akeanon word data
extends Node

var words: Dictionary = {}  # id -> word data

func _ready() -> void:
	_load()

func _load() -> void:
	var file = FileAccess.open("res://data/word_bank.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	var raw: Array = json.get_data()["words"]
	for w in raw:
		words[w["id"]] = w

func get_word(id: String) -> Dictionary:
	return words.get(id, {})

func get_words_for_area(area: String) -> Array:
	return words.values().filter(func(w): return w["area"] == area)
