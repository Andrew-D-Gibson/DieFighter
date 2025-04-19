class_name CanAcceptDice
extends Node2D

## Intended to work only with a RectangleShape2D
@export var collision: CollisionShape2D

signal die_accepted(die: Dice)


func _contains_point(point: Vector2) -> bool:
	if not collision or not collision.shape:
		return false
	
	var local_point = point - collision.global_position
	return collision.shape.get_rect().has_point(local_point)


func check_die_drop(die: Dice, drop_pos: Vector2) -> void:
	if is_visible_in_tree() and _contains_point(drop_pos):
		die_accepted.emit(die)
	
