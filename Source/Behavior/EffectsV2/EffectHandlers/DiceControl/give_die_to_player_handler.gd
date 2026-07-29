class_name GiveDieToPlayerHandler
extends EffectHandler

## Only transfers the die on the final repetition of the chain —
## context.repetitions is 0 once EffectChainV2 reaches the last pass.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return

	if not is_instance_valid(context.activator_die):
		return

	var event := GiveDieToPlayerEvent.new()
	event.activator_die = context.activator_die
	event.actor         = context.actor
	engine.inject_event(event)
