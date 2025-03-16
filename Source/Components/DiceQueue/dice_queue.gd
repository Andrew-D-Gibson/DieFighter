class_name DiceQueue
extends Node2D

var queue: Array[Dice]

signal die_added()
signal die_removed()


func add(die: Dice, preserve_value: bool = true) -> void:
	# Remove the die from it's previous host
	if die.host_queue:
		die.host_queue.remove(die)
		
	# Randomize the value if required
	if not preserve_value:
		die.value = randi_range(1,6)
		
	# Just in case we send a die back that's already in the queue, 
	# don't add it again
	if die not in queue:
		queue.append(die)
	
	die.host_queue = self
	die.draggable.home_position = global_position
	die_added.emit()


func remove(die: Dice) -> void:
	if die in queue:
		queue.erase(die)
		die_removed.emit()
