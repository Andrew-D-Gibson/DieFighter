class_name DiceReceptacle
extends Sprite2D

@export var dice_queue_spacing: int = 13
@export var dice_queue: DiceQueue

func _ready() -> void:
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	
func _add_die(die: Dice) -> void:
	# Make sure the engine is charged
	if Globals.player.engine_charge != Globals.player.max_engine_charge:
		return
		
	# Limit the dice in the queue to 1 (for now this is silly, but w/e)
	if len(dice_queue.queue) >= 1:
		return
	
	dice_queue.add(die)
	
	
# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue.position + Vector2(i * dice_queue_spacing, 0)


func _on_visibility_changed() -> void:
	for die in dice_queue.queue:
		die.visible = self.is_visible_in_tree()
