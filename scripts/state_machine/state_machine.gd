# state_machine.gd
# Generic FSM. Add State-derived child nodes; each child's node NAME
# is its state key (e.g. node "Idle" -> transition_to("Idle")).
class_name StateMachine
extends Node

## Node name of the state to start in. Defaults to first child if unset.
@export var initial_state: NodePath

## The body this FSM drives. Assign in inspector (drag Player node in).
@export var actor: Node

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self
			child.actor = actor

	if initial_state != NodePath() and has_node(initial_state):
		current_state = get_node(initial_state)
	elif states.size() > 0:
		current_state = states.values()[0]

	if current_state:
		current_state.enter.call_deferred()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

## Switch active state by node name, e.g. transition_to("Walk").
func transition_to(state_name: String) -> void:
	if not states.has(state_name):
		push_error("StateMachine: no state named '%s'" % state_name)
		return
	if current_state == states[state_name]:
		return
		
	var prev_name: String = ""
	if current_state:
		prev_name = current_state.name
		
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(prev_name)
