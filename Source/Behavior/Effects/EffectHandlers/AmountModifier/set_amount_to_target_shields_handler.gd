class_name SetAmountToTargetShieldsHandler
extends EffectHandler
## Sets running_amount to the first target's shields (0 without a target).
## After TARGET_PLAYER it reads the player's own: the read side of every
## shield payoff.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = 0
	if context.targets.is_empty() or not is_instance_valid(context.targets[0]):
		return
	var health: Health = context.targets[0].get("health") as Health
	if health:
		context.running_amount = health.shields
