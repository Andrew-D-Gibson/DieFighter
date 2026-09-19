class_name TargetRandomEnemyHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	
	if enemies.is_empty():
		context.targets = []
		return
		
	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, enemies) as Node]
