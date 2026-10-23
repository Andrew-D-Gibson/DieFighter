class_name IonDamageHandler
extends EffectHandler
## Ion damage at every target: one IonDamageEvent carrying the running amount.
## The doubling against shields happens when it lands (Health.take_ion_damage),
## after modifiers have had their say on the hit itself.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return

	var event: IonDamageEvent = IonDamageEvent.new()
	event.amount = context.running_amount
	_stamp(event, context)
	event.targets = context.targets.duplicate()

	engine.inject_event(event)
