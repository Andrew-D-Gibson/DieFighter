class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int
@export var spawning_path: Path2D

@export var fly_in_range: int = 100
@export var fly_in_time: float = 1.5


func _ready() -> void:
	Globals.enemy_manager = self
	
	# Force the baking on the curve where we spawn enemies
	spawning_path.curve.get_baked_points()
	
	Events.player_turn_over.connect(_run_enemy_turn)
	Events.enemy_left.connect(func(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		if ship in enemies:
			enemies.erase(ship)
	)
	Events.jump.connect(delete_all_enemies)
	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		Enemy.seed(scenario.seed)

		# Spawn the starting ships
		if len(scenario.starting_enemies) > 0:
			spawn_enemies(scenario.starting_enemies)
	)
	Events.start_scenario.connect(start_enemy_fly_in)
	
	
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
			
			
func _run_enemy_turn() -> void:
	# Create a copy of the enemies array to iterate over
	# This prevents issues if enemies are removed during iteration
	var current_enemies: Array[Enemy] = enemies.duplicate()
	
	while true:
		var dice_left: bool = false
		for enemy: Enemy in current_enemies:
			# Skip if enemy was removed
			if not enemy or not is_instance_valid(enemy):
				continue
				
			if len(enemy.dice_manager.queue) != 0:
				dice_left = true
				Globals.targeting_computer.target_enemy(enemy)
				await get_tree().create_timer(1).timeout
				await enemy.run_turn()
				
		
		if not dice_left:
			break
			
	Events.enemy_turn_over.emit()


func delete_all_enemies() -> void:
	# Needs to be queue_free'ed, not health reduced to 0
	# so we don't spawn rewards
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].disconnect_scenario_signals()
		enemies[i].queue_free()
	enemies = []


func kill_all_enemies() -> void:
	damage_all_enemies(10000)
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy: Enemy in enemies:
		enemy.health.change_shields(amount)
		
		
func damage_all_enemies(amount: int) -> void:
	for i: int in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(amount)
