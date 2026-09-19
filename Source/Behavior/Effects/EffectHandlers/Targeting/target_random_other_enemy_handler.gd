class_name TargetRandomOtherEnemyHandler
extends EffectHandler
## Picks one living enemy that isn't the actor.
##
## TARGET_RANDOM_ENEMY can (and usually will) pick the actor itself, which makes
## it useless for support ships. This is the targeting a medic or buffer needs.
## With no one else left alive it falls back to the actor, so a lone support ship
## still does something rather than silently wasting its turn.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var others: Array[Enemy] = []
	for enemy: Enemy in Globals.enemy_manager.get_alive_enemies():
		if enemy != context.actor:
			others.append(enemy)

	if others.is_empty():
		context.targets = [context.actor] if is_instance_valid(context.actor) else []
		return

	context.targets = [RNGManager.pick_random(RNGManager.Bucket.TARGETING, others) as Node]
