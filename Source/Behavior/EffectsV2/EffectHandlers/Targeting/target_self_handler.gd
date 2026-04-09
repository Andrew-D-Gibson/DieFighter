class_name TargetSelfHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(context.actor):
		context.targets = []
		return

	context.targets = [context.actor as Node]
