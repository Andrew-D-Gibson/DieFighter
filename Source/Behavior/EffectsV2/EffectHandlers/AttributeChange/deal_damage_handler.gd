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
		
	# Determine the base amount
	# This can be changed by modifiers later
	damage_event.amount = data.amount
	if data.inherit_die_amount:
		damage_event.amount = context.activator_die.value
	
	# Build out the event
	damage_event.actor = context.actor
	damage_event.effect_source = context.effect_source
	damage_event.activator_die = context.activator_die
	damage_event.die_value     = context.activator_die.value if context.activator_die else 0
	damage_event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	
	engine.inject_event(damage_event)
