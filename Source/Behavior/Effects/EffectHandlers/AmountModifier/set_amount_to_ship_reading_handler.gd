class_name SetAmountToShipReadingHandler
extends EffectHandler
## Sets (or, with add_to_amount, adds to) the running amount a number the
## flown ship's rules keep, named by string_param. See ShipRules.


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var value: int = ShipRules.reading(StringName(data.string_param), context)
	if data.add_to_amount:
		context.running_amount += value
	else:
		context.running_amount = value
