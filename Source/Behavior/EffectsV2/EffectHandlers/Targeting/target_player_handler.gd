class_name TargetPlayerHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		context.targets = []
		return
		
	context.targets = [Globals.player] as Array[Node]
