class_name JumpHandler
extends EffectHandler

## Encodes jump direction in data.amount's sign:
##   positive amount = jump forward
##   negative amount = jump backward
## data.inherit_die_amount = true uses the die's value (always jumps forward).

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var jump_delta: int = data.amount
	if data.inherit_die_amount and is_instance_valid(context.activator_die):
		jump_delta = context.activator_die.value

	var event := JumpEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.jump_delta    = jump_delta
	engine.inject_event(event)
