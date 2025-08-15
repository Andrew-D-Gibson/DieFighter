class_name TileDeckManager
extends Node2D

@onready var _raised: bool = false
@onready var _starting_position: Vector2 = global_position
var _raised_offset: int = 127

func _ready() -> void:
	pass
	
	
func _toggle_raised() -> void:
	_raised = !_raised
	_update_ui()
	
	
func _update_ui() -> void:
	var desired_pos: Vector2 = _starting_position
	if _raised:
		desired_pos += Vector2(0, -_raised_offset)

	# Calculate how far the raising motion needs to go
	# as a proportion of the total distance
	var normalized_vertical_distance_to_cover: float = abs(global_position.y - desired_pos.y)/_raised_offset

	# Set the tween time to be proportional to the distance needed to cover
	# This means the tween should move the node at around the same speed,
	# regardless of the distance needed to cover
	var tween_time: float = 0.75 * normalized_vertical_distance_to_cover
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		self,
		"global_position",
		desired_pos,
		tween_time
	).set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_IN_OUT)
