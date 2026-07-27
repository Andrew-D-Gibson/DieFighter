class_name JumpHandler
extends EffectHandler

## Reads jump_delta from context.running_amount.
## Positive = jump forward, negative = jump backward.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var jump_delta: int = context.running_amount

	var event := JumpEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.jump_delta    = jump_delta
	engine.inject_event(event)
