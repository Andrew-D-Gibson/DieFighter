class_name HealHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	# Instantiate a new event
	var heal_event: HealEvent = HealEvent.new()

	# Read the amount from the running amount (set by prior AMOUNT_MODIFIER steps)
	heal_event.amount = context.running_amount
	
	_stamp(heal_event, context)
	heal_event.targets       = context.targets.duplicate()  # snapshot, not a live reference
	
	engine.inject_event(heal_event)
