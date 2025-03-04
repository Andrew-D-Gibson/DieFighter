class_name DiceReceptacle
extends Sprite2D

@export var dice_queue_spacing: int = 13
@export var dice_queue: DiceQueue

func _ready() -> void:
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	
# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue.position + Vector2(i * dice_queue_spacing, 0)
