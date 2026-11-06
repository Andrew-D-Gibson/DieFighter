class_name TargetRandomEnemyHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# "You" is never picked by chance (FateSelf).
	var enemies: Array[Enemy] = FateSelf.by_chance(Globals.enemy_manager.get_alive_enemies())
	
	if enemies.is_empty():
		context.targets = []
		return
		
	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, enemies) as Node]
