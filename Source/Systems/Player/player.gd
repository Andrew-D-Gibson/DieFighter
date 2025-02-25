class_name Player
extends Node2D

@export_category('Graphics')
@export var dice_queue_spacing: int = 14

@export_category('Components')
@export var tile_grid: TileGrid
@export var dice_queue: DiceQueue
@export var health: Health
@export var end_turn_button: Control

signal player_turn_over()


func _ready() -> void:
	Globals.player = self
	
	dice_queue.die_added.connect(func():
		_update_dice_queue_locations()
		_make_newest_die_draggable()
	)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	tile_grid.tile_activation_complete.connect(_check_for_end_of_turn)
	
	end_turn_button.get_child(1).clicked.connect(func():
		end_turn_button.visible = false
		player_turn_over.emit()
	)
	end_turn_button.visible = false


# Update the dice desired locations in the world
func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.home_position = global_position + dice_queue.position + Vector2(i * dice_queue_spacing, 0)


func _make_newest_die_draggable() -> void:
	if dice_queue.queue[-1].draggable.state == Draggable.DragState.MOVING_WITH_CODE:
		dice_queue.queue[-1].draggable.state = Draggable.DragState.DEFAULT
		

func _process(delta: float) -> void:
	# Handle rearranging dice in the queue
	for die in dice_queue.queue:
		if die.draggable.state == Draggable.DragState.DRAGGING:
			var relative_mouse_pos = get_global_mouse_position() - global_position
			var current_queue_position = dice_queue.queue.find(die)
			
			# Create a rectangle that encompasses the current displayed dice queue
			var dice_queue_bounding_rect: Rect2 = Rect2(
				dice_queue.position.x - (dice_queue_spacing/2), # x
				dice_queue.position.y - (dice_queue_spacing/2), # y
				(len(dice_queue.queue) - 1) * dice_queue_spacing, # width
				dice_queue_spacing, # height
			)

			if dice_queue_bounding_rect.has_point(relative_mouse_pos):
				# Determine which queue position the mouse is hovering over
				var hovered_queue_position = int((relative_mouse_pos.x + dice_queue.position.x - (dice_queue_spacing/2)) / dice_queue_spacing)
				
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


func _check_for_end_of_turn() -> void:
	if len(dice_queue.queue) == 0:
		end_turn_button.visible = true


func start_player_turn() -> void:
	for die in dice_queue.queue:
		die.value = randi_range(1,6)
		die.draggable.state = Draggable.DragState.DEFAULT
