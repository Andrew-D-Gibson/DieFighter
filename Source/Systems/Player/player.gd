class_name Player
extends Node2D

@export_category('Graphics')
@export var dice_queue_offset: Vector2 = Vector2(0,0)
@export var dice_queue_spacing: int = 32

@export_category('Components')
@export var tile_grid: TileGrid
@export var dice_queue: DiceQueue
@export var health: Health


func _ready() -> void:
	Globals.player = self
	
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)


# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue_offset + Vector2(i * dice_queue_spacing, 0)


func _process(delta: float) -> void:
	# Handle rearranging dice in the queue
	for die in dice_queue.queue:
		if die.draggable.state == Draggable.DragState.DRAGGING:
			var relative_mouse_pos = get_global_mouse_position() - global_position
			var current_queue_position = dice_queue.queue.find(die)
			
			# Create a rectangle that encompasses the current displayed dice queue
			var dice_queue_bounding_rect: Rect2 = Rect2(
				dice_queue_offset.x - 16, # x
				dice_queue_offset.y - 16, # y
				(len(dice_queue.queue) - 1) * dice_queue_spacing, # width
				dice_queue_spacing, # height
			)

			if dice_queue_bounding_rect.has_point(relative_mouse_pos):
				# Determine which queue position the mouse is hovering over
				var hovered_queue_position = int((relative_mouse_pos.x + dice_queue_offset.x - 16) / dice_queue_spacing)
				
				# Make sure we limit the hovered location to the end of the queue
				hovered_queue_position = min(hovered_queue_position, len(dice_queue.queue)-1)
				
				# Switch the positions of the two dice, then update their locations
				if current_queue_position != hovered_queue_position:
					dice_queue.remove(die)
					dice_queue.queue.insert(hovered_queue_position, die)
					_update_dice_queue_locations()
			
			elif current_queue_position != len(dice_queue.queue)-1:
				dice_queue.remove(die)
				dice_queue.add(die, true)
