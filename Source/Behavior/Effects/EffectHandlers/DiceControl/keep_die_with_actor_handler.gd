class_name KeepDieWithActorHandler
extends EffectHandler
## Ends a chain by keeping the activator die instead of returning it.
##
## Only fires on the final repetition, matching GiveDieToTargetHandler — a
## multi-repetition chain shouldn't stash the die halfway through.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0:
		return

	if not is_instance_valid(context.activator_die):
		return

	var event := KeepDieWithActorEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
