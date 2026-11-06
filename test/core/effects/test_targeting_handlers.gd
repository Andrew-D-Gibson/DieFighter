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


func test_random_other_enemy_falls_back_to_a_lone_actor() -> void:
	var manager: EnemyManager = autofree(EnemyManager.new())
	var medic := _enemy()
	manager.enemies = [medic]
	Globals.enemy_manager = manager

	var context := EffectContext.new()
	context.actor = medic
	TargetRandomOtherEnemyHandler.new().apply(null, context, null)
	assert_eq(context.targets, [medic] as Array[Node], "with nobody else alive it tends to itself")


func test_every_enemy_and_random_enemy_leave_out_ships_that_are_not_hostile() -> void:
	var manager: EnemyManager = autofree(EnemyManager.new())
	var foe: Enemy = _enemy()
	foe.scenario_state = ScenarioShipState.new()
	foe.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	var ally: Enemy = _enemy()
	ally.scenario_state = ScenarioShipState.new()
	ally.scenario_state.attitude = Enemy.Attitude.FRIENDLY
	var bystander: Enemy = _enemy()
	bystander.scenario_state = ScenarioShipState.new()
	bystander.scenario_state.attitude = Enemy.Attitude.NEUTRAL
	manager.enemies = [ally, foe, bystander]
	Globals.enemy_manager = manager

	var context := EffectContext.new()
	TargetEnemiesHandler.new().apply(null, context, null)
	assert_eq(context.targets, [foe] as Array[Node])
	for run: int in range(10):
		RNGManager.seed_scenario(run)
		TargetRandomEnemyHandler.new().apply(null, context, null)
		assert_eq(context.targets, [foe] as Array[Node])

	manager.enemies = [ally]
	TargetRandomEnemyHandler.new().apply(null, context, null)
	assert_eq(context.targets, [] as Array[Node], "an ally alone is no one to hit")
