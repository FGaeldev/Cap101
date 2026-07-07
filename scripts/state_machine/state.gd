# state.gd
# Base class for FSM states. Extend, override what you need.
class_name State
extends Node

## Set by StateMachine on _ready. Lets state call transition_to().
var state_machine: StateMachine

## The actor (Player) this state controls. Set by StateMachine.
var actor: Node

## Fires once when this state becomes active. prev_state = name of state we left.
func enter(_prev_state: String = "") -> void:
	pass

## Fires once when leaving this state.
func exit() -> void:
	pass

## Runs every physics frame while active. Put movement logic here.
func physics_update(_delta: float) -> void:
	pass

## Runs every frame while active. Put non-physics logic here (rare for this game).
func update(_delta: float) -> void:
	pass
