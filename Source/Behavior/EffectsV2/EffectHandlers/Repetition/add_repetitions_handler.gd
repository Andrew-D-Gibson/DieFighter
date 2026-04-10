class_name AddRepetitionsHandler
extends EffectHandler

## Adds repetitions directly to the context, causing EffectChainV2 to loop
## additional times. data.amount is the number of extra repetitions to add.
##
## NOTE: handlers are stateless, so the old throttle (times_this_can_activate)
## is not implemented here. Avoid infinite chains at the authoring level.

func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.repetitions += data.amount
