class_name TargetRandomEnemyHandler
extends EffectHandler
## One random living hostile ship, or no one. Allies and civilians are never
## picked: a random hit must not turn a friend or start a fight the player
## never chose (TargetRandomHostileEnemyHandler.hostiles_in is the one rule).

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# "You" is never picked by chance (FateSelf, inside hostiles_in).
	var enemies: Array[Node] = TargetRandomHostileEnemyHandler.hostiles_in(Globals.enemy_manager.get_alive_enemies())

	if enemies.is_empty():
		context.targets = []
		return

	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, enemies) as Node]
