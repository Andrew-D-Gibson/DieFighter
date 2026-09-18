class_name Enemy
extends Node2D

const _SHIELDS_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_shields_hit.tres")
const _HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_health_hit.tres")
const _DEATH_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_death_explosion.tres")

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

## How many ships of this enemy's own faction have died since it arrived.
## Drives PoolSelection.SQUAD_LOSSES.
var squad_losses: int = 0

## How many full combat rounds have elapsed since this enemy arrived, counted
## whether or not it was given any dice. Drives PoolSelection.COMBAT_ROUNDS.
##
## Incremented on enemy_turn_over rather than player_turn_start so it's already
## settled by the time generate_turn_actions() reads it — the latter also runs
## off player_turn_start, and depending on signal connection order for
## correctness is a trap.
var rounds_in_combat: int = 0

## Optional: force specific actions (used by tutorial)
static var forced_actions: Array[EnemyActionResource] = []

var scenario_engine: ScenarioEngine = null:
	set = set_scenario_engine
	
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
		Events.play_sound.emit(_SHIELDS_HIT_SFX)
	)
	
	health.health_damaged.connect(graphics_manager.on_health_hit)
	health.health_damaged.connect(func():
		Events.play_sound.emit(_HEALTH_HIT_SFX)
	)


## Connects all scenario-related signals
func _connect_scenario_signals() -> void:
	Events.scenario_event.connect(_handle_scenario_event)
	Events.start_scenario.connect(trigger_state_effects)


func disconnect_scenario_signals() -> void:
	Events.scenario_event.disconnect(_handle_scenario_event)
	Events.start_scenario.disconnect(trigger_state_effects)
	

func _handle_scenario_event(event: ScenarioManager.ScenarioEvent) -> void:
		var new_state: ScenarioShipState = scenario_state.handle_scenario_event(event)
		graphics_manager.set_health_bar_attitude(new_state.attitude)
		
		if new_state != scenario_state:
			scenario_state = new_state
			trigger_state_effects()
		

## Connects all combat-related signals
func _connect_combat_signals() -> void:
	Events.combat_finished.connect(func() -> void:
		await get_tree().process_frame
		dice_manager.give_away_dice()
	)
	
	Events.player_turn_start.connect(generate_turn_actions)
	Events.enemy_turn_over.connect(func() -> void:
		rounds_in_combat += 1
	)
	Events.enemy_left.connect(_on_other_enemy_left)
	

## Counts losses among this enemy's own faction. Only actual deaths count — the
## same signal fires when a ship flees or when combat ends peacefully, and
## neither of those is something to get angry about.
func _on_other_enemy_left(ship: Enemy, faction: ScenarioManager.Faction) -> void:
	if ship == self or not is_instance_valid(ship):
		return
	if not scenario_state or faction != scenario_state.faction:
		return
	if ship.health.health > 0:
		return

	squad_losses += 1


## Connects the signals for the dice manager
func _connect_dice_manager_signals() -> void:
	dice_manager.die_added.connect(Events.enemy_received_die.emit)
	

## Called when the enemy dies
func _on_death() -> void:
	dice_manager.give_away_dice()
	Events.enemy_left.emit(self, scenario_state.faction)
	
	Events.play_sound.emit(_DEATH_SFX)
	
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


## Updates the health component's values, scaled by how deep into the run the
## player is. This is the single choke point every spawned enemy passes through,
## so it's the one place run difficulty needs to be applied.
func _update_health_from_resource() -> void:
	var scale_factor: float = 1.0
	if Globals.state_manager:
		scale_factor = Globals.state_manager.get_difficulty_multiplier()

	health.max_health = ceili(enemy_resource.max_health * scale_factor)
	health.health = health.max_health
	health.starting_shields = ceili(enemy_resource.starting_shields * scale_factor)
	health.shields = health.starting_shields


## Updates the health bar's position and values
func _update_health_bar() -> void:
	graphics_manager.set_health_bar_attitude(scenario_state.attitude)
	graphics_manager.set_health_bar_position(enemy_resource.health_bar_position)
	graphics_manager.set_health_bar_health(health)


## Updates the position and color of the dialogue manager
func _update_dialogue() -> void:
	dialogue_manager.position = enemy_resource.dialogue_offset


## Which of the enemy's action pools this turn's six slots are drawn from.
## The pool only changes which table the slots come from — the resolved slots
## are still shown in full before the player commits a die, so the telegraph
## stays honest either way.
func _current_pool_index() -> int:
	var pool_count: int = len(enemy_resource.action_options)
	if pool_count <= 1:
		return 0

	match enemy_resource.pool_selection:
		EnemyResource.PoolSelection.HEALTH_THRESHOLD:
			if health.max_health <= 0:
				return 0
			# Full health lands in the first pool, near-death in the last.
			var hurt: float = 1.0 - (float(health.health) / float(health.max_health))
			return clampi(int(hurt * pool_count), 0, pool_count - 1)

		EnemyResource.PoolSelection.SQUAD_LOSSES:
			return clampi(squad_losses, 0, pool_count - 1)

		EnemyResource.PoolSelection.COMBAT_ROUNDS:
			return clampi(rounds_in_combat, 0, pool_count - 1)

		_:
			return turns_alive % pool_count


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
		enemy_resource.action_options[_current_pool_index()]
	
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
		var rand_float: float = RNGManager.randf_range(RNGManager.Bucket.ENEMY_AI, 0, action_weights_sum)
		var choice_threshold = rand_float
		for option: EnemyActionOptionResource in this_turns_action_options.actions_possible:
			if choice_threshold > option.weight:
				choice_threshold -= option.weight
			else:
				turn_actions.append(option.get_action())
				break
				
	RNGManager.shuffle_array(RNGManager.Bucket.ENEMY_AI, turn_actions)
	
	# Make sure every action knows what dice activates it,
	# so it can display the correct hint text when clicked
	for i: int in range(6):
		turn_actions[i].activating_die_number = i+1
	

## Runs a full turn using all the dice in the queue,
## executing their actions sequentially 
func run_turn() -> void:
	var enemy_action_events: Array[EnemyActionEvent] = []
	
	for i in range(len(dice_manager.queue)):
		if not is_instance_valid(dice_manager.queue[i]):
			continue
		
		var die := dice_manager.queue[i]
		
		# Get the action for the chosen die
		var action := turn_actions[die.value - 1]

		var event := EnemyActionEvent.new()
		event.enemy = self
		event.activator_die = die
		event.die_value = die.value
		event.action = action
		
		enemy_action_events.append(event)
		
	for event: EnemyActionEvent in enemy_action_events:
		scenario_engine.queue_event(event)
	turns_alive += 1
	

## Triggers any effects associated with the current scenario state
func trigger_state_effects() -> void:
	dialogue_manager.show_dialogue(scenario_state.dialogue, scenario_state.faction)

	if not scenario_state.effects_on_enter_v2 or not scenario_engine:
		return

	var event: ScenarioStateEffectsEvent = ScenarioStateEffectsEvent.new()
	event.enemy = self
	event.chain = scenario_state.effects_on_enter_v2
	scenario_engine.queue_event(event)


## Re-targets the computer for this enemy
func _on_clicked() -> void:
	Globals.targeting_computer.target_enemy(self)
	
	
func set_scenario_engine(engine: ScenarioEngine) -> void:
	scenario_engine = engine
