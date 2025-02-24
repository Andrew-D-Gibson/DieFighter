class_name Enemy
extends Node2D

@export var enemy_resource: EnemyResource
		
@export_category('Components')
@export var dice_queue: DiceQueue
@export var health: Health

var ship_graphics: Node2D
var turn_actions: Array[EnemyActionResource]


func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	
	health.death.connect(queue_free)
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)


func _update_resource() -> void:
	# Set the ship's graphics
	if ship_graphics:
		ship_graphics.queue_free()
	ship_graphics = enemy_resource.ship_graphics_scene.instantiate()
	add_child(ship_graphics)
	
	# Set up the health component
	health.max_health = enemy_resource.max_health
	health.health = health.max_health
	health.starting_shields = enemy_resource.starting_shields
	health.shields = enemy_resource.starting_shields
	
	# Move and update the health bar as needed
	$EnemyHealthBar.position = enemy_resource.health_bar_position
	$EnemyHealthBar._set_health()
	$EnemyHealthBar._set_shields()
	
	# Create new actions for the coming turn
	_generate_turn_actions()
	
	
func _generate_turn_actions() -> void:
	# Clear the previous turn's actions
	turn_actions = []
	
	# Grab at least one of every listed action
	# Also sum up the likelihoods for later
	var action_likelihood_sum: float = 0
	for action in enemy_resource.actions_and_likelihoods.keys():
		turn_actions.append(action)
		action_likelihood_sum += enemy_resource.actions_and_likelihoods[action]
		
	# Randomly fill the rest of the list using the action likelihoods
	# Randomly choose 6 actions picking from our weighted list
	for i in range(6 - len(turn_actions)):
		var choice_threshold = randf_range(0, action_likelihood_sum)
		for action in enemy_resource.actions_and_likelihoods.keys():
			if choice_threshold > enemy_resource.actions_and_likelihoods[action]:
				choice_threshold -= enemy_resource.actions_and_likelihoods[action]
			else:
				turn_actions.append(action)
				break
				
	turn_actions.shuffle()


func _update_dice_queue_locations() -> void:
	for i in range(len(dice_queue.queue)):
		dice_queue.queue[i].draggable.state = Draggable.DragState.ENEMY_HOLDING
		dice_queue.queue[i].draggable.home_position = global_position + enemy_resource.dice_queue_position + Vector2(0, -i * 14)


func act_with_first_die() -> void:
	# Don't act if there's no dice in the queue
	if len(dice_queue.queue) == 0:
		return
		
	# Get the first die from the queue
	var die := dice_queue.queue[0]
	dice_queue.remove(die)
	
	# Get the action for the chosen die
	var action := turn_actions[die.value - 1]
	
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.source = self
	effect_variables.activator_die = die
		
	for effect_scene in action.effect_chain.keys():
		# Add the effect node to the scene
		var effect = effect_scene.instantiate()
		effect.amount = action.effect_chain[effect_scene]
		add_child(effect)
		
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
		
		# Remove the effect node from the scene
		effect.queue_free()
