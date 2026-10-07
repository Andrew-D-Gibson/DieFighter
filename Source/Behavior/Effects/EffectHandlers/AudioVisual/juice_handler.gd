class_name JuiceHandler
extends EffectHandler

## One handler for every authorable flourish (SHOCKWAVE through DIE_FLARE).
## They differ only in what JuiceEvent draws, so the handler just copies the
## authored parameters across. It reads data.amount, never running_amount,
## so a flourish can sit anywhere in a chain without disturbing the numbers
## around it. The one exception is CALLOUT's "{amount}" token, which reads
## running_amount precisely so it can show it.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := JuiceEvent.new()
	_stamp(event, context)
	event.kind = data.subtype
	event.targets = context.targets.duplicate()
	event.amount = data.amount
	event.multiplier = data.multiplier
	event.color = data.color
	event.text = data.string_param.replace("{amount}", str(context.running_amount))
	engine.inject_event(event)
