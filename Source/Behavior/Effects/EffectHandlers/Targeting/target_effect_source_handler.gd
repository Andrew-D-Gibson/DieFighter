class_name TargetEffectSourceHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var source = context.effect_source

	if not is_instance_valid(source):
		context.targets = []
		return

	context.targets = [source as Node]
