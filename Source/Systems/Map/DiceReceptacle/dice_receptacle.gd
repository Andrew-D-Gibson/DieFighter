class_name DiceReceptacle
extends Sprite2D

@export var dice_queue_spacing: int = 13
@export var dice_queue: DiceQueue

func _ready() -> void:
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	
func _add_die(die: Dice) -> void:
	# Make sure we're out of combat
	# This is probably bad for extensibility, but who knows what I'll need later
	if Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT:
		return
		
	# Limit the dice in the queue to 3
	if len(dice_queue.queue) >= 3:
		return
	
	dice_queue.add(die)
	
	
# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue.position + Vector2(i * dice_queue_spacing, 0)


func _on_visibility_changed() -> void:
	for die in dice_queue.queue:
		die.visible = self.is_visible_in_tree()
