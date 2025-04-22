class_name Enemy
extends Node2D

## The possible attitudes an enemy can have
enum Attitude {FRIENDLY, NEUTRAL, AGGRESSIVE}

## The resource containing the enemy's base stats and behavior
@export var enemy_resource: EnemyResource

## The current state of the enemy in the scenario
@export var scenario_state: ScenarioShipState

## The resource containing the rewards for defeating this enemy
@export var reward_resource: RewardResource

@export_category('Components')
## Manages the enemy's dice queue
@export var dice_manager: EnemyDiceManager

## Manages all visual aspects of the enemy
@export var graphics_manager: EnemyGraphicsManager

## Tracks the enemy's health and shields
@export var health: Health

## The scene to instantiate when showing action popups
@export var action_popup: PackedScene

## The actions the enemy will take this turn
var turn_actions: Array[EnemyActionResource]


## Initializes the enemy and connects all necessary signals
func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	
	_connect_health_signals()
	_connect_scenario_signals()
	_connect_combat_signals()


## Connects all health-related signals
func _connect_health_signals() -> void:
	health.death.connect(_on_death)
	health.shields_damaged.connect(graphics_manager.on_shields_hit)
	health.health_damaged.connect(graphics_manager.on_health_hit)


## Connects all scenario-related signals
func _connect_scenario_signals() -> void:
	Events.scenario_event.connect(func(event: ScenarioManager.ScenarioEvent):
		scenario_state = scenario_state.handle_scenario_event(event)
		graphics_manager.set_health_bar_attitude(scenario_state.attitude)
		trigger_state_effects()
	)
	
	Events.start_scenario.connect(trigger_state_effects)


## Connects all combat-related signals
func _connect_combat_signals() -> void:
	Events.combat_finished.connect(func():
		await get_tree().process_frame
		dice_manager.give_away_dice()
	)


## Called when the enemy dies
func _on_death() -> void:
	dice_manager.give_away_dice()
	Events.enemy_left.emit(self, scenario_state.faction)
	
	await graphics_manager.play_death_animation()

	# Spawn rewards
	Events.spawn_reward.emit(
		global_position, 
		reward_resource.money, 
		reward_resource.num_of_rewards,
		reward_resource.dice_probability
	)
			
	queue_free()


## Updates the enemy's components based on the enemy resource
func _update_resource() -> void:
	_update_graphics()
	_update_dice_queue()
	_update_health_from_resource()
	_update_health_bar()
	generate_turn_actions()


## Updates the enemy's graphics
func _update_graphics() -> void:
	graphics_manager.update_ship_graphics(enemy_resource.ship_graphics_scene)


## Updates the dice queue position
func _update_dice_queue() -> void:
	dice_manager.position = enemy_resource.dice_queue_position


## Updates the health component's values
func _update_health_from_resource() -> void:
	health.max_health = enemy_resource.max_health
	health.health = health.max_health
	health.starting_shields = enemy_resource.starting_shields
	health.shields = enemy_resource.starting_shields


## Updates the health bar's position and values
func _update_health_bar() -> void:
	graphics_manager.set_health_bar_attitude(scenario_state.attitude)
	graphics_manager.set_health_bar_position(enemy_resource.health_bar_position)
	graphics_manager.set_health_bar_health(health)


## Generates the actions the enemy will take this turn
func generate_turn_actions() -> void:
	# Clear the previous turn's actions
	turn_actions = []
	
	# Grab at least one of every listed action
	# Also sum up the likelihoods for later
	var action_weights_sum: float = 0
	for option in enemy_resource.action_options:
		if option.force_include:
			turn_actions.append(option.get_action())
		action_weights_sum += option.weight
		
	# Randomly fill the rest of the list using the action likelihoods
	# Randomly choose 6 actions picking from our weighted list
	for i in range(6 - len(turn_actions)):
		var choice_threshold = randf_range(0, action_weights_sum)
		for option in enemy_resource.action_options:
			if choice_threshold > option.weight:
				choice_threshold -= option.weight
			else:
				turn_actions.append(option.get_action())
				break
				
	turn_actions.shuffle()


## Uses the value of the first die in the queue to perform the 
## pre-chosen action
func act_with_first_die() -> void:
	# Don't act if there's no dice in the queue
	if len(dice_manager.queue) == 0:
		return
		
	# Get the first die from the queue
	var die := dice_manager.queue[0]
	die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
	
	# Get the action for the chosen die
	var action := turn_actions[die.value - 1]
	
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.actor = self
	effect_variables.effect_source = self
	effect_variables.activator_die = die
	
	
	# Move the die to in front of the enemy
	var tween_time = 0.25
	var tween = get_tree().create_tween()
	tween.tween_property(die, "global_position", global_position + Vector2(0,12), tween_time).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	await get_tree().create_timer(0.25).timeout
	
	# Make an action indicator popup
	var popup_time = 0.75
	var action_indicator = action_popup.instantiate()
	add_child(action_indicator)
	action_indicator.sprite.texture = action.info_texture
	action_indicator.popup_time = popup_time
	action_indicator.global_position = die.global_position + Vector2(0,12)
		
		
	for effect in action.effect_chain:
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
		
	Events.enemy_acted.emit(enemy_resource.enemy_name, action.name)
	

## Runs a full turn using all the dice in the queue,
## executing their actions sequentially 
func run_turn() -> void:
	while len(dice_manager.queue) > 0:
		await act_with_first_die()
	
	# Only generate new actions if we're still valid
	generate_turn_actions()
	

## Returns the enemy's current dialogue
func get_dialogue() -> String:
	var dialogue: String = scenario_state.dialogue
	if dialogue != '':
		return dialogue
	return "[color=gray]NOT ACCEPTING HAILS[/color]"


## Triggers any effects associated with the current scenario state
func trigger_state_effects() -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.actor = self
	effect_variables.effect_source = self
	
	for effect in scenario_state.effects_on_enter:
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
