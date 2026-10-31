class_name TargetRandomHostileEnemyHandler
extends EffectHandler
## Picks one living enemy that is hostile to the player, or no one.
##
## TARGET_RANDOM_ENEMY draws from every ship on the board, merchants and
## allies included. A passive the player doesn't aim (Spark Gap) must only
## ever hit a ship that is already fighting them: hitting a neutral would
## start a fight the player never chose, and hitting an ally mid-fight would
## turn it. With no hostile ship it targets nothing, so the hit fizzles.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var hostiles: Array[Node] = []
	if is_instance_valid(Globals.enemy_manager):
		hostiles = hostiles_in(Globals.enemy_manager.get_alive_enemies())
	if hostiles.is_empty():
		context.targets = hostiles
		return
	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, hostiles) as Node]


## The ships in [param ships] whose attitude is AGGRESSIVE.
static func hostiles_in(ships: Array) -> Array[Node]:
	var hostiles: Array[Node] = []
	for ship: Variant in ships:
		if not is_instance_valid(ship) or not ship is Enemy:
			continue
		var enemy: Enemy = ship
		if enemy.scenario_state != null \
				and enemy.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			hostiles.append(enemy)
	return hostiles
