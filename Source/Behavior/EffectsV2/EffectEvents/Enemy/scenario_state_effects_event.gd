class_name ScenarioStateEffectsEvent
extends EffectEvent

## The enemy whose scenario_state.effects_on_enter_v2 chain is firing.
var enemy: Enemy

## The chain to play.
var chain: EffectChainV2


func resolve(engine: ScenarioEngine) -> void:
	if not is_instance_valid(enemy):
		return

	var context: EffectContext = EffectContext.new()
	context.actor = enemy
	context.effect_source = enemy

	await chain.play(context, engine)
