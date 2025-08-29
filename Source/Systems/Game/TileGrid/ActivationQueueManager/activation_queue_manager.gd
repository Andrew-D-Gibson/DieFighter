class_name ActivationQueueManager
extends Node2D

## The queue of dice to activate when it's their turn
## This is @export'ed just for debugging purposes
@export var dice_activation_queue: Array[Dice]


func _ready() -> void:
	Globals.activation_queue_manager = self
	Events.tile_activation_complete.connect(_process_queue)
	
	Events.jump.connect(func() -> void:
		dice_activation_queue.clear()	
	)


func _process_queue() -> void:
	if len(dice_activation_queue) > 0:
		var die: Dice = dice_activation_queue[0]
		var die_owner = die.host_queue.get_parent()
		
		if is_instance_valid(die_owner) and die_owner is Tile:
			if die_owner.can_activate(die):
				dice_activation_queue.erase(die)
				die_owner.activate(die)
				
			else:
				_clear_activation_queue()
				
			
func add_die_to_queue(die: Dice) -> void:
	if not die:
		return
		
	dice_activation_queue.append(die)
	if len(dice_activation_queue) == 1:
		_process_queue()


func _clear_activation_queue() -> void:
	for die: Dice in dice_activation_queue:
		var die_owner = die.host_queue.get_parent()
		
		if is_instance_valid(die_owner) and die_owner is Tile:
			Globals.player.dice_manager.add(die, true, false)
			
	dice_activation_queue.clear()
