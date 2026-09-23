class_name DealDamageHandler
extends EffectHandler

## NOTE: This creates a single DamageEvent that targets ALL entries in
## context.targets. DamageEvent.resolve() iterates over them.
## If you need per-target independent modifier hooks, create one event
## per target here instead.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	# Instantiate a new event
	var damage_event: DamageEvent = DamageEvent.new()

	# Read the amount from the running amount (set by prior AMOUNT_MODIFIER steps)
	damage_event.amount = context.running_amount
	
	_stamp(damage_event, context)
	damage_event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	
	engine.inject_event(damage_event)
