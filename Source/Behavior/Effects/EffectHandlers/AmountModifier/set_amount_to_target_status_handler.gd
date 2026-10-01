class_name SetAmountToTargetStatusHandler
extends EffectHandler
## Sets running_amount to how many stacks of the string_param status the first
## target has (0 when it has none). The read side of every status payoff.


func apply(data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	context.running_amount = 0
	if context.targets.is_empty() or not is_instance_valid(context.targets[0]):
		return
	var status: StatusModifier = engine.find_status(context.targets[0], StringName(data.string_param))
	if status:
		context.running_amount = status.stacks
