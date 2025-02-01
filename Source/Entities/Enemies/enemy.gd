class_name Enemy
extends Node2D

@export var enemy_resource: EnemyResource
		
@export_category('Components')
@export var dice_queue: DiceQueue
@export var health: Health
@export var intent_indicator: IntentIndicator

var ship_graphics: Node2D
var turn_actions: Array[EnemyActionResource]


func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	print(turn_actions)


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
	
	# Move the intent indicators as needed
	$IntentIndicator.position = enemy_resource.intent_indicator_position
	
	
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
	
	intent_indicator.update_intent_indicators(turn_actions)
