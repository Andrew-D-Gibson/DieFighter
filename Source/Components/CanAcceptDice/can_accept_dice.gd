extends Node2D

var is_currently_accepting = true
@export var width: int
@export var height: int


func set_accepting_dice(new_state: bool) -> void:
	is_currently_accepting = new_state
