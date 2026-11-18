# examinable.gd -- a sign, board or display the player can look at. Interact
# (or tap) inside its area and it shows the lines of a dialogue scene, e.g.
# chapter4.json "examine_kasama_plaque". Text lives in the chapter's dialogue
# file like any other line, so it can use \ Akeanon markers and word_ids.
#
# Put it on the walkable tile(s) in front of the object (the object itself is
# usually solid): position = centre of that strip, area_size = its size in px.
extends Node2D

const INTERACTABLE := preload("res://scenes/components/interactable_component.tscn")

@export var chapter: String = "chapter4"
@export var scene_key: String = ""
@export var area_size: Vector2 = Vector2(16, 16)

var _busy: bool = false

func _ready() -> void:
	var ic: Node2D = INTERACTABLE.instantiate()
	ic.interact_label = "Look"
	ic.area_size = area_size
	add_child(ic)
	ic.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	if _busy or CutsceneManager.is_playing() or DialogueUI.is_active():
		return
	var lines: Array = ChapterLoader.get_scene_lines(chapter, scene_key)
	if lines.is_empty():
		push_warning("examinable: no lines for %s/%s" % [chapter, scene_key])
		return
	_busy = true
	var dialogue := DialogueComponent.new()
	dialogue.dialogue_lines = lines
	add_child(dialogue)
	dialogue.dialogue_ended.connect(func():
		_busy = false
		dialogue.queue_free())
	dialogue.start_dialogue()
