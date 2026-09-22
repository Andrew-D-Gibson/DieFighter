class_name Reward
extends Node2D

@export var dice_scene: PackedScene
@export var money_pickup_scene: PackedScene
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
	
	var offered: Array[Node2D] = _build_offered_rewards(reward_resource)
	if offered.is_empty():
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
	
	bounding_box.shape.size.x = reward_spacing * offered.size()
	
	var total_length := reward_spacing * (offered.size() - 1)
	var start_offset := -total_length / 2

	for i in range(offered.size()):
		var reward: Node2D = offered[i]
		
		add_child(reward)
		
		reward.draggable.drag_started.connect(Events.show_systems.emit)
		reward.draggable.drag_ended.connect(_end_reward)
		reward.global_position = global_position + Vector2(start_offset,0) + Vector2(i * reward_spacing, 0)
		reward.draggable.home_position = reward.global_position
		reward.draggable.emit_reached_new_home = false
		reward.draggable.floating_enabled = true
		
		rewards.append(reward)
		

## Builds (but does not parent) everything this offer puts in front of the
## player, left to right: the tile/dice choices, then the money pickup if the
## resource authored one.
##
## Kept separate from the layout loop above so "what is on offer" is decided
## before any of it is on screen — the caller needs the final count to size
## the bounding box, and an empty result means there is no offer to show.
func _build_offered_rewards(reward_resource: RewardResource) -> Array[Node2D]:
	var offered: Array[Node2D] = []
	var possible_tile_rewards = Globals.reward_manager.get_possible_tile_rewards()

	for i in range(reward_resource.num_of_rewards):
		# Give the player a dice instead of a tile if we can't fit another tile, 
		# we can't give the player a tile they don't already have,
		# or randomly otherwise
		if Globals.tile_grid.find_available_grid_pos() == Vector2i(-1,-1)\
		or len(possible_tile_rewards) == 0\
		or RNGManager.randf(RNGManager.Bucket.REWARDS) <= reward_resource.dice_probability:
			offered.append(dice_scene.instantiate())
			
		# Make a tile reward
		else:
			var chosen_resource: TileResource
			if len(forced_rewards) > 0:
				chosen_resource = forced_rewards.pop_front()
			else:
				chosen_resource = Globals.reward_manager.pick_weighted_tile_reward(possible_tile_rewards)
			possible_tile_rewards.erase(chosen_resource)
			offered.append(Globals.tile_grid.create_tile(chosen_resource))

	if reward_resource.max_money_pickup > 0 and money_pickup_scene:
		var pickup: MoneyPickup = money_pickup_scene.instantiate()
		pickup.amount = RNGManager.randi_range(
			RNGManager.Bucket.REWARDS,
			reward_resource.min_money_pickup,
			reward_resource.max_money_pickup
		)
		offered.append(pickup)

	return offered
		

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
		Events.reward_tile_taken.emit()
		
	elif chosen_reward is Dice:
		chosen_reward.reparent(Globals.player, true)
		Globals.player.dice_manager.add(chosen_reward)
		Globals.player.num_of_dice += 1
		
	elif chosen_reward is MoneyPickup:
		chosen_reward.claim()
		Events.reward_money_taken.emit()
		
	Events.reward_picked.emit()
	queue_free()


func _spawn_money_particles(amount: int) -> void:
	# Parented to this reward's own parent rather than to the reward, which is
	# freed as soon as the player takes something.
	MoneyParticle.spawn_payout(
		get_parent(), global_position, amount, money_particle_scene
	)
