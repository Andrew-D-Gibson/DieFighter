## HealHandler
## ============================================================
## Creates a HealEvent and enqueues it into the engine.
##
## EffectData fields used:
##   amount             — HP to restore (if inherit_die_amount is false)
##   inherit_die_amount — if true, use the activator die's face value instead
## ============================================================

class_name HealHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var base_amount: int = data.amount
	if data.inherit_die_amount and context.activator_die:
		base_amount = context.activator_die.value

	var event := HealEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.die_value     = context.activator_die.value if context.activator_die else 0
	event.targets       = context.targets.duplicate()
	event.amount        = base_amount

	engine.enqueue_event(event)
