class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int


func _ready() -> void:
	Globals.enemy_manager = self
	Events.player_turn_over.connect(_run_enemy_turn)
	Events.enemy_died.connect(_remove_dead_enemies)
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
		enemy.reward_resource = enemies_to_spawn[i].reward_resource
		enemy.scenario_state = enemies_to_spawn[i].starting_state
		enemy.position = Vector2(-(enemy_spacing / float(2)) + (spacing * (i+1)), 0)
		
		enemies.append(enemy)
		add_child(enemy)
	
	
func get_alive_enemies() -> Array[Enemy]:
	_remove_dead_enemies()
	return enemies
	

func _remove_dead_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		if not enemies[i] or enemies[i].health.health == 0:
			enemies.remove_at(i)
			
			
func _run_enemy_turn() -> void:
	for enemy in enemies:
		while len(enemy.dice_queue.queue) > 0:
			enemy.act_with_first_die()
			await enemy.action_completed
			await get_tree().create_timer(0.5).timeout
			
		# Now that this enemy is done this turn, generate a new list of actions
		enemy.generate_turn_actions()
	
	Events.enemy_turn_over.emit()


func kill_all_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(1000000)
	enemies = []
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy in enemies:
		enemy.health.change_shields(amount)
