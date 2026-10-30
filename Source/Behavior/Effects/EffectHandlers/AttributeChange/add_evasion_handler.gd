class_name AddEvasionHandler
extends EffectHandler
## Adds running_amount percentage points to the player's evasion until the
## enemy turn ends (AddEvasionEvent, Juke Thrusters).


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event: AddEvasionEvent = AddEvasionEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	engine.inject_event(event)
