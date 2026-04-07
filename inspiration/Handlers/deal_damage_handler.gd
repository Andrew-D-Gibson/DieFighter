## DealDamageHandler
## ============================================================
## Creates one DamageEvent and enqueues it into the engine.
##
## EffectData fields used:
##   amount             — base damage (used if inherit_die_amount is false)
##   inherit_die_amount — if true, use the activator die's face value instead
##
## The DamageEvent's 'amount' field is what Modifier before-hooks will
## adjust (e.g., DoubleDamageModifier doubles it before resolution).
##
## NOTE: This creates a single DamageEvent that targets ALL entries in
## context.targets. DamageEvent.resolve() iterates over them.
## If you need per-target independent modifier hooks, create one event
## per target here instead.
## ============================================================

class_name DealDamageHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	# Determine the base damage amount.
	var base_amount: int = data.amount
	if data.inherit_die_amount and context.activator_die:
		base_amount = context.activator_die.value

	# Build the event — modifiers will adjust 'amount' before resolve() runs.
	var event := DamageEvent.new()
	event.actor         = context.actor
	event.effect_source = context.effect_source
	event.activator_die = context.activator_die
	event.die_value     = context.activator_die.value if context.activator_die else 0
	event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	event.amount        = base_amount

	engine.enqueue_event(event)
