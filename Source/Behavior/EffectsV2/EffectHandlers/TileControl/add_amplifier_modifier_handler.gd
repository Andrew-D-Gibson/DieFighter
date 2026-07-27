class_name AddAmplifierModifierHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: AddAmplifierModifierEvent = AddAmplifierModifierEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.targets       = context.targets.duplicate()
	event.amount        = data.amount
	if data.inherit_die_amount and is_instance_valid(context.activator_die):
		event.amount = context.activator_die.value
	engine.inject_event(event)
