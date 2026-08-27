# field_notes.gd — Chapter 2 tutorial trigger object.
# Interacting loads scene_2_field_notes from chapter2.json, which contains
# the challenge_gate line for ch2_tutorial_field_notes. Once passed,
# MapManager unlocks bakhawan_ecopark (see chapter2.json unlock_target and
# regions.json gate_challenge_id entry).
# Follows the standard ~15-line NPC component-wiring pattern (TDD §3) —
# not a copy of examinable_object.gd's puzzle_panel path, unrelated system.
extends StaticBody2D

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var dialogue: DialogueComponent = $DialogueComponent

const DIALOGUE_CHAPTER := "chapter2"
const DIALOGUE_SCENE_KEY := "scene_2_field_notes"

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	dialogue.dialogue_lines = ChapterLoader.get_scene_lines(DIALOGUE_CHAPTER, DIALOGUE_SCENE_KEY)
	dialogue.start_dialogue()
