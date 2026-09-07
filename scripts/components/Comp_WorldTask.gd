# Comp_WorldTask.gd — attach to a giver (NPC) or target (object) alongside
# InteractableComponent. Does not replace InteractableComponent or Comp_Dialogue
# — self-connects to the sibling InteractableComponent's `interacted` signal,
# same pattern npc_elder.gd uses for DialogueComponent. InteractableComponent
# never calls this directly.
#
# Parent node still needs its own InteractableComponent + sibling Area2D named
# "InteractArea" — that requirement is unchanged, enforced by
# InteractableComponent itself, not duplicated here.
class_name WorldTaskComponent
extends Node

@export_enum("giver", "target") var mode: String = "giver"
@export var task_id: String = ""
## Target mode only — which step index in the task's `steps` array this
## object satisfies. Ignored in giver mode.
@export var required_step: int = 0

@onready var interactable: InteractableComponent = $"../InteractableComponent"

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_interactor: Node) -> void:
	match mode:
		"giver":
			TaskManager.start_task(task_id)
		"target":
			if TaskManager.is_task_active(task_id) and TaskManager.get_current_step(task_id) == required_step:
				TaskManager.advance_task_step(task_id)
