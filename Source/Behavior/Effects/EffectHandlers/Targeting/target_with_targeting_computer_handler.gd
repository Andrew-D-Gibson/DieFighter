class_name TargetWithTargetingComputerHandler
extends EffectHandler

func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	var target: Enemy = Globals.targeting_computer.targeted_enemy

	if not is_instance_valid(target):
		context.targets = []
		return

	context.targets = [target as Node]
