class_name AddAmplifierStatusHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.effect_source):
		return

	var event := AddAmplifierStatusEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.amount        = data.amount
	if data.inherit_die_amount and is_instance_valid(context.activator_die):
		event.amount = context.activator_die.value
	engine.queue_event(event)
