extends "res://test/helpers/die_fighter_test.gd"
## ScenarioResource.enemy_hull_multiplier / enemy_damage_multiplier: an elite
## fields the same ships as an ordinary fight, only tougher. The multipliers
## must reach every ship the encounter puts on the board, launched ones too.

const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const ENEMY_MANAGER_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyManager/enemy_manager.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const ATTACK_PLAYER: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")


func _pirate_state() -> ScenarioShipState:
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	state.attitude = Enemy.Attitude.AGGRESSIVE
	return state


func _roster() -> Array[EnemyStateRewardResource]:
	var spawn: EnemyStateRewardResource = EnemyStateRewardResource.new()
	spawn.enemy_resource = INTERCEPTOR
	spawn.starting_state = _pirate_state()
	var roster: Array[EnemyStateRewardResource] = [spawn]
	return roster


func _elite(hull: float, damage: float) -> ScenarioResource:
	var scenario: ScenarioResource = ScenarioResource.new()
	scenario.enemy_hull_multiplier = hull
	scenario.enemy_damage_multiplier = damage
	return scenario


## A ship whose one pool is a flat 5-damage attack, so every slot rolls 5
## before the encounter's multiplier.
func _flat_attacker(damage_multiplier: float) -> Enemy:
	var option: EnemyActionOptionResource = EnemyActionOptionResource.new()
	option.base_action = ATTACK_PLAYER
	option.weight = 1.0
	option.min_amount = 5
	option.max_amount = 5
	var pool: EnemyTurnActionList = EnemyTurnActionList.new()
	pool.actions_possible = [option] as Array[EnemyActionOptionResource]
	var resource: EnemyResource = INTERCEPTOR.duplicate()
	resource.action_options = [pool] as Array[EnemyTurnActionList]

	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = resource
	ship.scenario_state = _pirate_state()
	ship.scenario_damage_multiplier = damage_multiplier
	return add_child_autofree(ship)


func test_an_encounter_multiplies_the_hull_of_the_ships_it_spawns() -> void:
	var plain: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	plain.spawn_enemies(_roster())
	var elite: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	elite.spawn_enemies(_roster(), _elite(2.0, 1.0))

	var base: int = plain.enemies[0].health.max_health
	assert_almost_eq(float(elite.enemies[0].health.max_health), base * 2.0, 1.0)
	assert_eq(elite.enemies[0].health.health, elite.enemies[0].health.max_health)


func test_a_launched_ship_takes_its_launchers_multipliers() -> void:
	var manager: EnemyManager = add_child_autofree(ENEMY_MANAGER_SCENE.instantiate())
	manager.spawn_enemies(_roster(), _elite(1.5, 1.4))
	var launcher: Enemy = manager.enemies[0]

	var launched: Enemy = await manager.launch_ship(INTERCEPTOR, launcher)

	assert_eq(launched.scenario_hull_multiplier, 1.5)
	assert_eq(launched.scenario_damage_multiplier, 1.4)
	assert_eq(launched.health.max_health, launcher.health.max_health)


func test_an_encounter_multiplies_rolled_intents() -> void:
	var plain: Enemy = _flat_attacker(1.0)
	var elite: Enemy = _flat_attacker(1.4)

	plain.generate_turn_actions(EnemyActionSituation.for_ship(plain), false)
	elite.generate_turn_actions(EnemyActionSituation.for_ship(elite), false)

	var base: int = plain.turn_actions[0].intent_amount
	for action: EnemyActionResource in elite.turn_actions:
		assert_eq(action.intent_amount, ceili(base * 1.4))
