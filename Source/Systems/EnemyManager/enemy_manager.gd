class_name EnemyManager
extends Node2D

var enemies: Array[Enemy]

@export var enemy_base_scene: PackedScene
@export var enemy_spacing: int

signal enemy_turn_ended()


func _ready() -> void:
	Globals.enemy_manager = self
	
	Globals.player.player_turn_over.connect(_run_enemy_turn)
	

func spawn_enemies(enemy_resources: Array[EnemyResource]) -> void:
	var spacing = enemy_spacing / float(len(enemy_resources) + 1)
	
	for i in range(len(enemy_resources)):
		var enemy = enemy_base_scene.instantiate()
		enemy.enemy_resource = enemy_resources[i]
		enemy.position = Vector2(-(enemy_spacing / float(2)) + (spacing * (i+1)), -80)
		
		enemy.health.death.connect(_remove_dead_enemies)
		
		enemies.append(enemy)
		add_child(enemy)


func kill_all_enemies() -> void:
	for enemy in enemies:
		enemy.queue_free()
	enemies = []
	

func _remove_dead_enemies() -> void:
	for i in range(len(enemies)-1, -1, -1):
		if not enemies[i] or enemies[i].health.health == 0:
			enemies.remove_at(i)
			
			
func _run_enemy_turn() -> void:
	for enemy in enemies:
		while len(enemy.dice_queue.queue) > 0:
			enemy.act_with_first_die()
	enemy_turn_ended.emit()
