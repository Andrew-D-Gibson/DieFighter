class_name SetAmountToDieValueHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if is_instance_valid(context.activator_die):
		context.running_amount = context.activator_die.value
