class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int
@export var spawning_path: Path2D


func _ready() -> void:
	Globals.enemy_manager = self
	
	# Force the baking on the curve where we spawn enemies
	spawning_path.curve.get_baked_points()
	
	Events.player_turn_over.connect(_run_enemy_turn)
	Events.enemy_left.connect(func(ship: Enemy, _faction: ScenarioManager.Faction) -> void:
		if ship in enemies:
			enemies.erase(ship)
	)
	Events.load_scenario.connect(func(_scenario: ScenarioResource):
		# Needs to be queue_free'ed, not health reduced to 0
		# so we don't spawn rewards
		for i in range(len(enemies)-1, -1, -1):
			enemies[i].queue_free()
		enemies = []
	)
	
	
func spawn_enemies(enemies_to_spawn: Array[EnemyStateRewardResource]) -> void:
	var spacing = enemy_spacing / float(len(enemies_to_spawn) + 1)
	
	for i in range(len(enemies_to_spawn)):
		var enemy = enemy_base_scene.instantiate()
		enemy.enemy_resource = enemies_to_spawn[i].enemy_resource
		enemy.position = get_point_along_path(enemies_to_spawn[i].spawning_path_location)
		enemy.reward_resource = enemies_to_spawn[i].reward_resource
		enemy.scenario_state = enemies_to_spawn[i].starting_state
		#enemy.position = Vector2(-(enemy_spacing / float(2)) + (spacing * (i+1)), 0)
		
		enemies.append(enemy)
		add_child(enemy)
	
	
func get_point_along_path(proportion: float) -> Vector2:
	var total_length: float = spawning_path.curve.get_baked_length()
	return spawning_path.curve.sample_baked(proportion * total_length)
	
	
func get_alive_enemies() -> Array[Enemy]:
	_remove_dead_enemies()
	return enemies
	
	
func get_faction_ships(faction: ScenarioManager.Faction) -> Array[Enemy]:
	var faction_ships: Array[Enemy] = []
	_remove_dead_enemies()
	for enemy in enemies:
		if enemy.scenario_state.faction == faction:
			faction_ships.append(enemy)
	return faction_ships
	

func _remove_dead_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		if not enemies[i] or enemies[i].health.health == 0:
			enemies.remove_at(i)
			
			
func _run_enemy_turn() -> void:
	# Create a copy of the enemies array to iterate over
	# This prevents issues if enemies are removed during iteration
	var current_enemies = enemies.duplicate()
	
	while true:
		var dice_left: bool = false
		for enemy in current_enemies:
			# Skip if enemy was removed
			if not enemy or not is_instance_valid(enemy):
				continue
				
			if len(enemy.dice_manager.queue) != 0:
				dice_left = true
				await enemy.run_turn()
		
		if not dice_left:
			break
			
	Events.enemy_turn_over.emit()


func kill_all_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(1000000)
	enemies = []
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy in enemies:
		enemy.health.change_shields(amount)
