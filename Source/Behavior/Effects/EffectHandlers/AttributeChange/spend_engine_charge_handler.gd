class_name SpendEngineChargeHandler
extends EffectHandler
## Spends engine charge as a cost.
##
## The cost is data.amount when authored, falling back to context.running_amount
## so a variable price composes (SET_TO_DIE_VALUE -> SPEND_ENGINE_CHARGE charges
## the die's face value). Either way it is a positive number; the event turns it
## into a subtraction.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: SpendEngineChargeEvent = SpendEngineChargeEvent.new()
	event.amount = data.amount if data.amount != 0 else context.running_amount

	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.die_value     = context.activator_die.value if context.activator_die else 0

	engine.inject_event(event)
