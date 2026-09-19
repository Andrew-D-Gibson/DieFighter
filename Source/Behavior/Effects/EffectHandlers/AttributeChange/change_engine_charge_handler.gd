class_name ChangeEngineChargeHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	# Instantiate a new event
	var event: ChangeEngineChargeEvent = ChangeEngineChargeEvent.new()

	# Read the amount from the running amount (set by prior AMOUNT_MODIFIER steps)
	event.amount = context.running_amount
			
	# Build out the event
	event.actor = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.die_value     = context.activator_die.value if context.activator_die else 0

	engine.inject_event(event)
