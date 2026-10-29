class_name SetTargetsHighestDieHandler
extends EffectHandler
## Turns the highest die each target holds to `amount` (1 when unset): Cryo
## Lance defuses the big die an enemy already holds, before it can spend it.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.targets.is_empty():
		return
	var event := ChangeHeldDiceEvent.new()
	_stamp(event, context)
	event.targets = context.targets.duplicate()
	event.change = ChangeHeldDiceEvent.Change.SET_HIGHEST
	event.face = clampi(data.amount, 1, 6) if data.amount > 0 else 1
	event.color = data.color
	engine.inject_event(event)
