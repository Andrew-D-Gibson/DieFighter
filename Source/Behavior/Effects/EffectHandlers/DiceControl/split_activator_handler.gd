class_name SplitActivatorHandler
extends EffectHandler
## Splits the activator die in two (SplitActivatorEvent). Once per activation,
## on the last repetition, like every die hand-off: a die splits once however
## many times its chain repeats.


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	if context.repetitions > 0 or not is_instance_valid(context.activator_die):
		return

	var event := SplitActivatorEvent.new()
	_stamp(event, context)
	engine.inject_event(event)
