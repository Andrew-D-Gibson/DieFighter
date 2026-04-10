class_name ChangeActivatorValueHandler
extends EffectHandler

## data.amount: the value to set the activator die to.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := ChangeActivatorValueEvent.new()
	event.activator_die = context.activator_die
	event.actor         = context.actor
	event.amount        = data.amount
	engine.queue_event(event)
