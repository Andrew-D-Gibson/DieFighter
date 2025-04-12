extends Node2D

@export var dice_scene: PackedScene
@export var tile_scene: PackedScene
@export var bounding_box: CollisionShape2D

var rewards: Array[Node2D]


func give_reward(money: int, dice_probability: float) -> void:
	Globals.player.money += money

	for i in range(3):
		var reward: Node2D
		
		# Make a dice reward if we can't fit another tile or randomly otherwise
		if Globals.tile_grid.find_available_grid_pos() == Vector2i(-1,-1)\
		or randf() <= dice_probability:
			reward = dice_scene.instantiate()
			
		# Make a tile reward
		else:
			reward = tile_scene.instantiate()
			reward.tile_resource = Globals.reward_manager.possible_tile_rewards.pick_random()
			
		
		add_child(reward)
		reward.draggable.drag_ended.connect(_end_reward)
		reward.global_position = global_position + Vector2((i - 1) * 26, 0)
		reward.draggable.home_position = reward.global_position
		reward.draggable.emit_reached_new_home = false
		
		rewards.append(reward)
		

func _end_reward(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	# Don't do anything if the drag ended within the reward window
	if bounding_box.shape.get_rect().has_point(local_end_position):
		return
		
	var chosen_reward = draggable.get_parent()
			
	for reward in rewards:
		reward.draggable.drag_ended.disconnect(_end_reward)
		if reward != chosen_reward:
			reward.queue_free()
			continue
	rewards = []
	
	if chosen_reward is Tile:
		chosen_reward.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
		chosen_reward.tile_activation_complete.connect(Globals.tile_grid.tile_activation_complete.emit)
		chosen_reward.reparent(Globals.tile_grid, true)
		
		Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)
		
	elif chosen_reward is Dice:
		chosen_reward.reparent(Globals.player, true)
		Globals.player.dice_queue.add(chosen_reward)
		Globals.player.num_of_dice += 1
		
	Events.reward_picked.emit()
	queue_free()
