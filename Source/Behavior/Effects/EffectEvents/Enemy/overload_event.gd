class_name OverloadEvent
extends EffectEvent
## A ship took more dice than its breaker can stand. Instead of spending them it
## vents them all back to the player, raises its threshold and plays its
## overload_chain (see EnemyResource.overload_threshold).

var enemy: Enemy


func is_amplifiable() -> bool:
	return false


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(enemy):
		return

	Juice.callout(enemy, "OVERLOAD!", Globals.yellow, true)
	Juice.sparkle(enemy.get_parent(), Juice.anchor_of(enemy), Globals.yellow, 18, 70.0)
	Events.camera_shake_small.emit()
	enemy.vent_overload()

	var chain: EffectChain = enemy.enemy_resource.overload_chain
	if chain == null:
		return
	var context: EffectContext = EffectContext.new()
	context.actor = enemy
	context.effect_source = enemy
	await chain.play(context, engine)
