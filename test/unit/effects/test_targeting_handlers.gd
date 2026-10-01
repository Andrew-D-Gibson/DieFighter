extends "res://test/helpers/die_fighter_test.gd"
## Targeting handlers: what ends up in context.targets.

const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")


func _enemy() -> Enemy:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 5
	enemy.health.health = 5
	return enemy


func test_target_enemies_targets_every_living_enemy() -> void:
	var manager: EnemyManager = autofree(EnemyManager.new())
	var a := _enemy()
	var b := _enemy()
	manager.enemies = [a, b]
	Globals.enemy_manager = manager

	var context := EffectContext.new()
	TargetEnemiesHandler.new().apply(null, context, null)
	assert_eq(context.targets, [a, b] as Array[Node])

	# A copy, not the manager's own list: later steps retarget the context.
	context.targets.clear()
	assert_eq(manager.enemies.size(), 2)
