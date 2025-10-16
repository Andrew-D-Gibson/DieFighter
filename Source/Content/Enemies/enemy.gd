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

## Manages showing the enemy's dialogue
@export var dialogue_manager: EnemyDialogueManager

## Manages all visual aspects of the enemy
@export var graphics_manager: EnemyGraphicsManager

## Tracks the enemy's health and shields
@export var health: Health

## The scene to instantiate when showing action popups
@export var action_popup: PackedScene

## The clickable region to target this enemy
@export var clickable_region: CollisionShape2D

## The actions the enemy will take this turn
var turn_actions: Array[EnemyActionResource]
var moving_in_world: bool = false

## The number of turns this enemy has lived
@onready var turns_alive: int = 0

## Static RNG instance for choosing actions
static var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Optional: force specific actions (used by tutorial)
static var forced_actions: Array[EnemyActionResource] = []


var explosion_particles: PackedScene = preload("uid://566ykra4buin")


## Initializes the enemy and connects all necessary signals
func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	
	_connect_health_signals()
	_connect_scenario_signals()
	_connect_combat_signals()
	_connect_dice_manager_signals()


func _process(_delta: float) -> void:
	if moving_in_world:
		dice_manager._update_dice_queue_locations()
		

## Connects all health-related signals
func _connect_health_signals() -> void:
	health.death.connect(_on_death)
	health.shields_damaged.connect(graphics_manager.on_shields_hit)
	health.shields_damaged.connect(func():
		Events.play_sound.emit('enemy_shields_hit')
	)
	
	health.health_damaged.connect(graphics_manager.on_health_hit)
	health.health_damaged.connect(func():
		Events.play_sound.emit('enemy_health_hit')
	)


## Connects all scenario-related signals
func _connect_scenario_signals() -> void:
	Events.scenario_event.connect(_handle_scenario_event)
	Events.start_scenario.connect(trigger_state_effects)


func disconnect_scenario_signals() -> void:
	Events.scenario_event.disconnect(_handle_scenario_event)
	Events.start_scenario.disconnect(trigger_state_effects)
	

func _handle_scenario_event(event: ScenarioManager.ScenarioEvent):
		var new_state: ScenarioShipState = scenario_state.handle_scenario_event(event)
		graphics_manager.set_health_bar_attitude(new_state.attitude)
		
		if new_state != scenario_state:
			scenario_state = new_state
			trigger_state_effects()
		scenario_state = new_state
		

## Connects all combat-related signals
func _connect_combat_signals() -> void:
	Events.combat_finished.connect(func():
		await get_tree().process_frame
		dice_manager.give_away_dice()
	)
	
	Events.player_turn_start.connect(generate_turn_actions)
	

## Connects the signals for the dice manager
func _connect_dice_manager_signals() -> void:
	dice_manager.die_added.connect(Events.enemy_received_die.emit)
	

## Seeds the rng at the start of the scenario
## (Called by the enemy manager)
static func seed(seed_value: int) -> void:
	rng.seed = seed_value
	

## Called when the enemy dies
func _on_death() -> void:
	dice_manager.give_away_dice()
	Events.enemy_left.emit(self, scenario_state.faction)
	
	Events.play_sound.emit('enemy_death_explosion')
	
	# Create explosion particles
	var explosion = explosion_particles.instantiate()
	explosion.color = Globals.red
	explosion.amount = health.max_health * 5
	add_child(explosion)

	# Spawn rewards
	Events.spawn_reward.emit(
		global_position, 
		reward_resource
	)
	
	await graphics_manager.play_death_animation()
	queue_free()


## Updates the enemy's components based on the enemy resource
func _update_resource() -> void:
	_update_graphics()
	_update_dice_queue()
	_update_health_from_resource()
	_update_health_bar()
	_update_dialogue()
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


## Updates the position and color of the dialogue manager
func _update_dialogue() -> void:
	dialogue_manager.position = enemy_resource.dialogue_offset


## Generates the actions the enemy will take this turn
func generate_turn_actions() -> void:
	# Clear the previous turn's actions
	turn_actions = []
	
	# Add any forced actions
	if len(forced_actions) > 0:
		var last_action_index_to_grab: int = min(6, len(forced_actions))
		turn_actions.append_array(forced_actions.slice(0, last_action_index_to_grab))
		
		forced_actions = forced_actions.slice(last_action_index_to_grab)
	
	var this_turns_action_options: EnemyTurnActionList = \
		enemy_resource.action_options[
			turns_alive % len(enemy_resource.action_options)
		]
	
	# Grab at least one of every action that has "force_include"
	# and sum up the likelihoods of all actions for later
	var action_weights_sum: float = 0
	for option: EnemyActionOptionResource in this_turns_action_options.actions_possible:
		if option.force_include:
			turn_actions.append(option.get_action())
		action_weights_sum += option.weight
		
	# With the forced actions and the "force_include" options, 
	# we might be over the required 6 actions
	if len(turn_actions) >= 6:
		turn_actions = turn_actions.slice(0,6)
		return
		
	# Randomly fill the rest of the list using the action likelihoods
	# Randomly choose 6 actions picking from our weighted list
	for i in range(6 - len(turn_actions)):
		var rand_float: float = rng.randf_range(0, action_weights_sum)
		var choice_threshold = rand_float
		for option: EnemyActionOptionResource in this_turns_action_options.actions_possible:
			if choice_threshold > option.weight:
				choice_threshold -= option.weight
			else:
				turn_actions.append(option.get_action())
				break
				
	turn_actions.shuffle()
	
	# Make sure every action knows what dice activates it,
	# so it can display the correct hint text when clicked
	for i: int in range(6):
		turn_actions[i].activating_die_number = i+1
	

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
	var tween_time: float = 0.75
	var adjusted_tween_time: float = tween_time / Globals.animation_speed
	var tween = get_tree().create_tween()
	tween.tween_property(die, "global_position", global_position + Vector2(0,12), adjusted_tween_time).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	await get_tree().create_timer(0.25).timeout
	
	# Make an action indicator popup
	var popup_time: float = 0.75
	var action_indicator = action_popup.instantiate()
	add_child(action_indicator)
	action_indicator.sprite.texture = action.info_texture
	action_indicator.popup_time = popup_time
	action_indicator.global_position = die.global_position + Vector2(0,12)
		
	Events.enemy_used_die.emit(self, die.value)
		
	await action.effect_chain.play(effect_variables)
		
	Events.enemy_acted.emit(enemy_resource.enemy_name, action.name)
	

## Runs a full turn using all the dice in the queue,
## executing their actions sequentially 
func run_turn() -> void:
	while len(dice_manager.queue) > 0:
		await act_with_first_die()
	turns_alive += 1
	

## Triggers any effects associated with the current scenario state
func trigger_state_effects() -> void:
	dialogue_manager.show_dialogue(scenario_state.dialogue, scenario_state.faction)
	
	if not scenario_state.effects_on_enter:
		return
		
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.actor = self
	effect_variables.effect_source = self
	
	await scenario_state.effects_on_enter.play(effect_variables)


## Re-targets the computer for this enemy
func _on_clicked() -> void:
	Globals.targeting_computer.target_enemy(self)
