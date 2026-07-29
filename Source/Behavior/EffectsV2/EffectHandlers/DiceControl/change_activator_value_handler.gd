class_name ChangeActivatorValueHandler
extends EffectHandler

## context.running_amount: the value to set the activator die to.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := ChangeActivatorValueEvent.new()
	event.activator_die = context.activator_die
	event.actor         = context.actor
	event.amount        = context.running_amount
	engine.inject_event(event)
