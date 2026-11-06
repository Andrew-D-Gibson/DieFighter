class_name TargetRandomHostileEnemyHandler
extends EffectHandler
## Picks one living enemy that is hostile to the player, or no one.
##
## Now the same pick as TARGET_RANDOM_ENEMY (every "enemy" effect is
## hostile-only); kept because authored tiles (Spark Gap) store this ordinal.
## [method hostiles_in] is the single rule for who counts as an enemy: hitting
## a neutral would start a fight the player never chose, and hitting an ally
## mid-fight would turn it. With no hostile ship it targets nothing, so the
## hit fizzles.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var hostiles: Array[Node] = []
	if is_instance_valid(Globals.enemy_manager):
		hostiles = hostiles_in(Globals.enemy_manager.get_alive_enemies())
	if hostiles.is_empty():
		context.targets = hostiles
		return
	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, hostiles) as Node]


## The ships in [param ships] whose attitude is AGGRESSIVE. Never "You",
## which nothing picks by chance (FateSelf).
static func hostiles_in(ships: Array) -> Array[Node]:
	var hostiles: Array[Node] = []
	for ship: Variant in ships:
		if not is_instance_valid(ship) or not ship is Enemy or FateSelf.is_self(ship):
			continue
		var enemy: Enemy = ship
		# A ship with no scenario state is a plain enemy: only one known to be
		# on the player's side (friendly or neutral) is left out.
		if not EnemyActionSituation.sides_with_player(enemy):
			hostiles.append(enemy)
	return hostiles
