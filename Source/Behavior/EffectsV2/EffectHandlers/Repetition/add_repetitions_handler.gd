class_name AddRepetitionsHandler
extends EffectHandler

## Adds repetitions directly to the context, causing EffectChainV2 to loop
## additional times. context.running_amount is the number of extra repetitions to add.
##
## NOTE: handlers are stateless, so the old throttle (times_this_can_activate)
## is not implemented here. Avoid infinite chains at the authoring level.

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.repetitions += context.running_amount
