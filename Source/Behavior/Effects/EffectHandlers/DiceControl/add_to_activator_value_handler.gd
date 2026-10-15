class_name AddToActivatorValueHandler
extends EffectHandler

## context.running_amount: how far to raise the activator die's face.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.activator_die):
		return

	var event := AddToActivatorValueEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	engine.inject_event(event)
