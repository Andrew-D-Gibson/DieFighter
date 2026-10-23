class_name JuiceHandler
extends EffectHandler

## One handler for every authorable flourish (SHOCKWAVE onwards: through
## DIE_FLARE, then the LASER and MISSILE shots).
## They differ only in what JuiceEvent draws, so the handler just copies the
## authored parameters across. It reads data.amount, never running_amount,
## so a flourish can sit anywhere in a chain without disturbing the numbers
## around it. The exceptions are CALLOUT's tokens: "{amount}" reads
## running_amount and "{die}" the activator die's face, precisely so they can
## show them.

func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := JuiceEvent.new()
	_stamp(event, context)
	event.kind = data.subtype
	event.targets = context.targets.duplicate()
	event.amount = data.amount
	event.multiplier = data.multiplier
	event.color = data.color
	event.flags = data.juice_flags
	event.text = data.string_param.replace("{amount}", str(context.running_amount))
	if is_instance_valid(context.activator_die):
		event.text = event.text.replace("{die}", str(context.activator_die.value))
	engine.inject_event(event)
