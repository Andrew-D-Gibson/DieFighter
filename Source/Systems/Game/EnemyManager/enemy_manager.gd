class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int
@export var spawning_path: Path2D

@export var fly_in_range: int = 100
@export var fly_in_time: float = 1.5

var enemies_jumping: bool = false
var screen_size: Vector2 = Vector2(320, 180)

var scenario_engine: ScenarioEngine = null:
	set = set_scenario_engine
	
	
func _ready() -> void:
	Globals.enemy_manager = self
	
	# Force the baking on the curve where we spawn enemies
	spawning_path.curve.get_baked_points()
	
	Events.player_turn_over.connect(func() -> void:
		# Don't automatically run the turn if the tutorial is handling it
		if Globals.tutorial_manager.tutorial_will_trigger_enemy_turns:
			return
		run_enemy_turn()
	)
	Events.enemy_left.connect(func(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		if ship in enemies:
			enemies.erase(ship)
	)
	Events.jump.connect(start_enemy_jump_animation)
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		# Clean up any remaining jumping enemies before loading new scenario
		if enemies_jumping:
			delete_all_enemies()
		
		# Spawn the starting ships
		if len(scenario.starting_enemies) > 0:
			spawn_enemies(scenario.starting_enemies)
	)
	Events.start_scenario.connect(start_enemy_fly_in)
	
	
func _process(delta: float) -> void:
	if enemies_jumping:
		_update_jumping_enemies(delta)
	
	
func spawn_enemies(enemies_to_spawn: Array[EnemyStateRewardResource]) -> void:
	for i: int in range(len(enemies_to_spawn)):
		var enemy: Enemy = enemy_base_scene.instantiate()
		enemy.enemy_resource = enemies_to_spawn[i].enemy_resource
		enemy.position = enemy.enemy_resource.graphics_scene_offset \
			+ Vector2(0, -fly_in_range) \
			+ get_point_along_path(enemies_to_spawn[i].spawning_path_location)
		enemy.reward_resource = enemies_to_spawn[i].reward_resource
		enemy.scenario_state = enemies_to_spawn[i].starting_state

		enemies.append(enemy)
		add_child(enemy)


func start_enemy_fly_in() -> void:
	for enemy: Enemy in enemies:
		if len(Enemy.forced_actions) > 0:
			enemy.generate_turn_actions()
			
		var fly_in_tween: Tween = get_tree().create_tween()
		fly_in_tween.tween_property(
			enemy,
			"position",
			enemy.position + Vector2(0, fly_in_range),
			fly_in_time
		).set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
		# Re-enable bobbing animation after spawn tween completes
		await fly_in_tween.finished
		Events.enemy_flew_in.emit()
		enemy.graphics_manager.start_bob_tween()
	
	
func get_point_along_path(proportion: float) -> Vector2:
	var total_length: float = spawning_path.curve.get_baked_length()
	return spawning_path.curve.sample_baked(proportion * total_length)
	
	
func move_ship_to_point_on_path(ship: Enemy, proportion: float) -> void:
	var tween_time: float = 0.75
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		ship, 
		'global_position', 
		get_point_along_path(proportion),
		tween_time
	)\
	.set_trans(Tween.TRANS_QUAD)\
	.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	
	
func get_alive_enemies() -> Array[Enemy]:
	_remove_dead_enemies()
	return enemies
	
	
func get_faction_ships(faction: ScenarioManager.Faction) -> Array[Enemy]:
	var faction_ships: Array[Enemy] = []
	_remove_dead_enemies()
	for enemy: Enemy in enemies:
		if enemy.scenario_state.faction == faction:
			faction_ships.append(enemy)
	return faction_ships
	

func _remove_dead_enemies() -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		if not enemies[i] or enemies[i].health.health == 0:
			enemies.remove_at(i)
			
			
func run_enemy_turn() -> void:
	# Create a copy of the enemies array to iterate over
	# This prevents issues if enemies are removed during iteration
	var current_enemies: Array[Enemy] = enemies.duplicate()
	
	for enemy: Enemy in current_enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
			
		if len(enemy.dice_manager.queue) <= 0:
			continue
			
		enemy.run_turn()
		
	await scenario_engine.finished_processing_queue
	Events.enemy_turn_over.emit()


func start_enemy_jump_animation() -> void:
	enemies_jumping = true
	for enemy: Enemy in enemies:
		if not enemy or not is_instance_valid(enemy):
			continue
		enemy.moving_in_world = true
		enemy.graphics_manager.stop_bob_tween()
		# Disable clickable region
		if enemy.clickable_region:
			enemy.clickable_region.disabled = true


func _update_jumping_enemies(delta: float) -> void:
	if not Globals.background_manager:
		return
		
	var parallax_level: int = 1  # Match medium debris
	var speed: float = Globals.background_manager.global_speed * \
					  Globals.background_manager.get_parallax_speed(parallax_level)
	
	for i: int in range(len(enemies) - 1, -1, -1):
		var enemy: Enemy = enemies[i]
		if not enemy or not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
			
		enemy.global_position.y += delta * speed
		
		if enemy.global_position.y > screen_size.y + 50:  # Off-screen offset
			enemy.disconnect_scenario_signals()
			enemy.queue_free()
			enemies.remove_at(i)
	
	# Reset flag when all enemies are gone
	if len(enemies) == 0:
		enemies_jumping = false


func delete_all_enemies() -> void:
	# Needs to be queue_free'ed, not health reduced to 0
	# so we don't spawn rewards
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].disconnect_scenario_signals()
		enemies[i].queue_free()
	enemies = []
	enemies_jumping = false


func kill_all_enemies() -> void:
	damage_all_enemies(10000)
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy: Enemy in enemies:
		enemy.health.change_shields(amount)
		
		
func damage_all_enemies(amount: int) -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(amount)
		
		
func set_scenario_engine(engine: ScenarioEngine) -> void:
	scenario_engine = engine
	
	for enemy: Enemy in get_alive_enemies():
		enemy.scenario_engine = engine
