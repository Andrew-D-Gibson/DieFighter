class_name SetAmountToTargetDiceHeldHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = 0
	if context.targets.is_empty() or not is_instance_valid(context.targets[0]):
		return

	var queue: DiceQueue = context.targets[0].get("dice_manager") as DiceQueue
	if queue:
		context.running_amount = queue.queue.size()
