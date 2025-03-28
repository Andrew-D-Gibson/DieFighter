class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int


func _ready() -> void:
	Globals.enemy_manager = self
	Events.player_turn_over.connect(_run_enemy_turn)
	

func spawn_enemies(enemy_resources: Array[EnemyResource]) -> void:
	var spacing = enemy_spacing / float(len(enemy_resources) + 1)
	
	for i in range(len(enemy_resources)):
		var enemy = enemy_base_scene.instantiate()
		enemy.enemy_resource = enemy_resources[i]
		enemy.position = Vector2(-(enemy_spacing / float(2)) + (spacing * (i+1)), 0)
		
		enemy.death.connect(func():
			_remove_dead_enemies()
			Events.enemy_died.emit()
			
			if len(enemies) == 0:
				Events.combat_finished.emit()
		)
		
		enemies.append(enemy)
		add_child(enemy)


func kill_all_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		enemies[i].health.take_damage(1000000)
		
		
func shield_all_enemies(amount: int) -> void:
	for enemy in enemies:
		enemy.health.change_shields(amount)
	
	
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
