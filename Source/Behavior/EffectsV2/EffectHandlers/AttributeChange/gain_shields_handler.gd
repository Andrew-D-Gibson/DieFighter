class_name GainShieldsHandler
extends EffectHandler

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
		
	# Instantiate a new event
	var shield_event: ShieldEvent = ShieldEvent.new()
		
	# Determine the base amount
	# This can be changed by modifiers later
	if data.inherit_die_amount:
		shield_event.amount = context.activator_die.value
		
	
	# Build out the event
	shield_event.actor = context.actor
	shield_event.effect_source = context.effect_source
	shield_event.activator_die = context.activator_die
	shield_event.die_value     = context.activator_die.value if context.activator_die else 0
	shield_event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	
	engine.queue_event(shield_event)
