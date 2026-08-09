class_name Reward
extends Node2D

@export var dice_scene: PackedScene
@export var money_particle_scene: PackedScene
@export var bounding_box: CollisionShape2D

var rewards: Array[Node2D]

## Optional: force specific rewards (used by tutorial)
static var forced_rewards: Array[TileResource] = []


func _ready() -> void:
	hide()
	
	Events.jump.connect(queue_free)
	

func give_reward(reward_resource: RewardResource) -> void:
	#Globals.player.money += money
	var money: int = RNGManager.randi_range(
		RNGManager.Bucket.REWARDS, reward_resource.min_money, reward_resource.max_money
	)
	_spawn_money_particles(money)
	
	await get_tree().create_timer(2).timeout
	
	if reward_resource.num_of_rewards == 0:
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
	
	bounding_box.shape.size.x = reward_spacing * reward_resource.num_of_rewards
	
	var total_length := reward_spacing * (reward_resource.num_of_rewards - 1)
	var start_offset := -total_length / 2

	var possible_tile_rewards = Globals.reward_manager.get_possible_tile_rewards()

	for i in range(reward_resource.num_of_rewards):
		var reward: Node2D
		
		# Give the player a dice instead of a tile if we can't fit another tile, 
		# we can't give the player a tile they don't already have,
		# or randomly otherwise
		if Globals.tile_grid.find_available_grid_pos() == Vector2i(-1,-1)\
		or len(possible_tile_rewards) == 0\
		or RNGManager.randf(RNGManager.Bucket.REWARDS) <= reward_resource.dice_probability:
			reward = dice_scene.instantiate()
			
		# Make a tile reward
		else:
			var chosen_resource: TileResource
			if len(forced_rewards) > 0:
				chosen_resource = forced_rewards.pop_front()
			else:
				chosen_resource = RNGManager.pick_random(RNGManager.Bucket.REWARDS, possible_tile_rewards)
			possible_tile_rewards.erase(chosen_resource)
			reward = Globals.tile_grid.create_tile(chosen_resource)
			
		
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
		Globals.tile_grid.receive_tile(chosen_reward, end_position)
		
	elif chosen_reward is Dice:
		chosen_reward.reparent(Globals.player, true)
		Globals.player.dice_manager.add(chosen_reward)
		Globals.player.num_of_dice += 1
		
	Events.reward_picked.emit()
	queue_free()


func _spawn_money_particles(amount: int) -> void:
	var num_of_large_particles: int = floor(amount / MoneyParticle.money_amount.LARGE)
	var num_of_small_particles: int = amount % MoneyParticle.money_amount.LARGE
	
	for i: int in range(num_of_large_particles + num_of_small_particles):
		var particle: MoneyParticle = money_particle_scene.instantiate()
		particle.amount = MoneyParticle.money_amount.LARGE if i < num_of_large_particles else MoneyParticle.money_amount.SMALL
		
		add_sibling(particle)
		particle.global_position = global_position
