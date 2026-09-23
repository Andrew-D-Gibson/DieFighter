class_name GiveDieToTargetHandler
extends EffectHandler

## Only transfers the die on the final repetition of the chain,
## matching the old GiveDieToTargetEffect behavior.

func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	# context.repetitions was already decremented by EffectChain before this runs.
	# A value > 0 means more loops remain — skip until the last one.
	if context.repetitions > 0:
		return

	if not is_instance_valid(context.activator_die):
		return

	var event := GiveDieToTargetEvent.new()
	_stamp(event, context)
	event.targets       = context.targets.duplicate()
	engine.inject_event(event)
