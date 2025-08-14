extends Node2D

@export var dice_scene: PackedScene
@export var tile_scene: PackedScene
@export var money_particle_scene: PackedScene
@export var bounding_box: CollisionShape2D

var rewards: Array[Node2D]


func _ready() -> void:
	hide()
	
	Events.load_scenario.connect(func(_scenario: ScenarioResource):
		queue_free()
	)
	

func give_reward(money: int, num_of_rewards: int, dice_probability: float) -> void:
	#Globals.player.money += money
	_spawn_money_particles(money)
	
	await get_tree().create_timer(2).timeout
	
	if num_of_rewards == 0:
		queue_free()
		return
		
	# Fade in
	show()
	var tween_time: float = 0.5
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		self, 
		"modulate:a", 
		1.0, 
		tween_time
	).from(0.0)
	
	var reward_spacing: int = 26
	
	bounding_box.shape.size.x = reward_spacing * num_of_rewards
	
	var total_length := reward_spacing * (num_of_rewards - 1)
	var start_offset := -total_length / 2

	var possible_tile_rewards = Globals.reward_manager.get_possible_tile_rewards()

	for i in range(num_of_rewards):
		var reward: Node2D
		
		# Give the player a dice instead of a tile if we can't fit another tile, 
		# we can't give the player a tile they don't already have,
		# or randomly otherwise
		if Globals.tile_grid.find_available_grid_pos() == Vector2i(-1,-1)\
		or len(possible_tile_rewards) == 0\
		or randf() <= dice_probability:
			reward = dice_scene.instantiate()
			
		# Make a tile reward
		else:
			reward = tile_scene.instantiate()
			reward.tile_resource = possible_tile_rewards.pick_random()
			
			# Remove the chosen resource from the "possible" list so there's no repeats
			possible_tile_rewards.erase(reward.tile_resource)
			
		
		add_child(reward)
		
		reward.draggable.drag_started.connect(Events.show_systems.emit)
		reward.draggable.drag_ended.connect(_end_reward)
		reward.global_position = global_position + Vector2(start_offset,0) + Vector2(i * reward_spacing, 0)
		reward.draggable.home_position = reward.global_position
		reward.draggable.emit_reached_new_home = false
		reward.draggable.floating_enabled = true
		
		rewards.append(reward)
		

func _end_reward(draggable: Draggable, end_position: Vector2) -> void:
	var local_end_position = end_position - bounding_box.global_position
	# Don't do anything if the drag ended within the reward window
	if bounding_box.shape.get_rect().has_point(local_end_position):
		return
		
	var chosen_reward = draggable.get_parent()
	chosen_reward.draggable.drag_started.disconnect(Events.show_systems.emit)
	chosen_reward.draggable.drag_ended.disconnect(_end_reward)
	
	
	if chosen_reward is Tile:
		chosen_reward.draggable.floating_enabled = false
		chosen_reward.draggable.drag_ended.connect(Globals.tile_grid._drop_tile_on_grid_pos)
		chosen_reward.reparent(Globals.tile_grid, true)
		
		Globals.tile_grid._drop_tile_on_grid_pos(draggable, end_position)
		
	elif chosen_reward is Dice:
		chosen_reward.reparent(Globals.player, true)
		Globals.player.dice_manager.add(chosen_reward)
		chosen_reward.draggable.drag_started.connect(Events.hide_comms.emit)
		Globals.player.num_of_dice += 1
		
	Events.reward_picked.emit()
	queue_free()


func _spawn_money_particles(amount: int) -> void:
	var num_of_large_particles: int = floor(amount / MoneyParticle.money_amount.LARGE)
	var num_of_small_particles: int = amount % MoneyParticle.money_amount.LARGE
	
	print('For amount: ', amount)
	print('Spawning ', num_of_large_particles, ' large particles')
	print('Spawning ', num_of_small_particles, ' small particles')
	
	for i: int in range(num_of_large_particles + num_of_small_particles):
		var particle: MoneyParticle = money_particle_scene.instantiate()
		particle.amount = MoneyParticle.money_amount.LARGE if i < num_of_large_particles else MoneyParticle.money_amount.SMALL
		
		add_sibling(particle)
		particle.global_position = global_position
