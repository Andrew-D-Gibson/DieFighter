class_name HealHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
		
	# Instantiate a new event
	var heal_event: HealEvent = HealEvent.new()
		
	# Determine the base amount
	# This can be changed by modifiers later
	heal_event.amount = data.amount
	if data.inherit_die_amount:
		heal_event.amount = context.activator_die.value
	
	# Build out the event
	heal_event.actor = context.actor
	heal_event.effect_source = context.effect_source
	heal_event.activator_die = context.activator_die
	heal_event.die_value     = context.activator_die.value if context.activator_die else 0
	heal_event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	
	engine.inject_event(heal_event)
