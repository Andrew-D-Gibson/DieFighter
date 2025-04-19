class_name Enemy
extends Node2D

enum Attitude {FRIENDLY, NEUTRAL, AGGRESSIVE}

@export var enemy_resource: EnemyResource
@export var scenario_state: ScenarioShipState
@export var reward_resource: RewardResource

		
@export_category('Components')
@export var dice_queue: DiceQueue
@export var health: Health
@export var action_popup: PackedScene
@export var shakeable: Shakeable
@export var attitude_indicator: AnimatedSprite2D


@export_category('Graphics')
@export var ship_graphics: Node2D
@export var hit_flash_time: float = 0.5
@export var death_explosion: PackedScene
var turn_actions: Array[EnemyActionResource]
var tween: Tween

signal action_completed()


func _ready() -> void:
	assert(enemy_resource)
	_update_resource()
	_start_bob_tween()
	
	health.death.connect(_on_death)
	health.shields_damaged.connect(_on_shields_hit)
	health.health_damaged.connect(_on_health_hit)
	
	dice_queue.die_added.connect(_update_dice_queue_locations)
	dice_queue.die_removed.connect(_update_dice_queue_locations)
	
	$EnemyHealthBar.set_attitude_indicator(scenario_state.attitude)
	Events.scenario_event.connect(func(event: ScenarioManager.ScenarioEvent):
		scenario_state = scenario_state.handle_scenario_event(event)
		$EnemyHealthBar.set_attitude_indicator(scenario_state.attitude)
		trigger_state_effects()
	)
	Events.start_scenario.connect(trigger_state_effects)
	
	Events.combat_finished.connect(func():
		await get_tree().process_frame
		_give_away_dice()
	)


func _on_shields_hit() -> void:
	_stop_bob_tween()
	shakeable.small_shake()
	_shields_hit_flash()
	await shakeable.shake_ended
	_start_bob_tween()


func _on_health_hit() -> void:
	_stop_bob_tween()
	shakeable.large_shake()
	_health_hit_flash()
	await shakeable.shake_ended
	_start_bob_tween()
	

func _stop_bob_tween() -> void:
	if tween:
		tween.kill()
		

func _start_bob_tween() -> void:
	if tween:
		tween.kill()
		
	var tween_time = randf_range(2, 4)
	tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, 'global_position', self.global_position + Vector2(0, 8), tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ship_graphics, 'global_position', self.global_position, tween_time/2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()


func _on_death() -> void:
	_give_away_dice()
	Events.enemy_died.emit(self.scenario_state.faction)
	
	$EnemyHealthBar.visible = false
	
	# Fade out the ship graphics
	var tween_time: float = 0.75
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "modulate", Color(1,1,1,0), tween_time)
	
	
	# Spawn the death explosion and wait
	var explosion = death_explosion.instantiate()
	add_sibling(explosion)
	explosion.global_position = self.global_position
	
	await explosion.animation_finished

	# Spawn rewards
	Events.spawn_reward.emit(
		global_position, 
		reward_resource.money, 
		reward_resource.dice_probability
	)
			
	queue_free()
	
	
# Give dice away to other enemies if possible or the player if not	
func _give_away_dice() -> void:
	var enemies = Globals.enemy_manager.get_alive_enemies()
	var other_enemies = []
	for enemy in enemies:
		if enemy != self:
			other_enemies.append(enemy)

	for i in range(len(dice_queue.queue)-1, -1, -1):
		var die = dice_queue.queue[i]
		die.draggable.state = Draggable.DragState.MOVING_WITH_CODE
		
		if len(other_enemies) == 0:
			Globals.player.dice_queue.add(die)
		else:
			other_enemies.pick_random().dice_queue.add(die)


func _update_resource() -> void:
	# Set the ship's graphics
	if ship_graphics:
		ship_graphics.queue_free()
	ship_graphics = enemy_resource.ship_graphics_scene.instantiate()
	add_child(ship_graphics)
	
	# Set up shaking the graphics
	shakeable.node_to_shake = ship_graphics
	
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
	generate_turn_actions()
	
	
func generate_turn_actions() -> void:
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

		
	action_completed.emit()


func _health_hit_flash() -> void:
	ship_graphics.material.set_shader_parameter('color', Globals.red)
	
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 1, hit_flash_time * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, hit_flash_time * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	
func _shields_hit_flash() -> void:
	ship_graphics.material.set_shader_parameter('color', Globals.blue)
	
	var tween = get_tree().create_tween()
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 1, hit_flash_time * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ship_graphics, "material:shader_parameter/flash_amount", 0, hit_flash_time * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	
func get_dialogue() -> String:
	var dialogue: String = scenario_state.dialogue
	if dialogue != '':
		return dialogue
	return "[color=gray]NOT ACCEPTING HAILS[/color]"


func trigger_state_effects() -> void:
	# Set up the effects variables for chaining effects
	var effect_variables = EffectVariables.new()
	effect_variables.actor = self
	effect_variables.effect_source = self
	
	for effect in scenario_state.effects_on_enter:
		# Play the effect, recording the change in variables
		await effect.play(effect_variables)
