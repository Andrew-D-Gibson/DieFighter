class_name AdvanceShipMechanismHandler
extends EffectHandler
## Steps the flown ship's mechanism by the running amount
## (AdvanceShipMechanismEvent). Runs on every repetition: an echoed Ratchet
## turns the ring twice.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.running_amount == 0:
		return
	var event := AdvanceShipMechanismEvent.new()
	_stamp(event, context)
	event.amount = context.running_amount
	engine.inject_event(event)
