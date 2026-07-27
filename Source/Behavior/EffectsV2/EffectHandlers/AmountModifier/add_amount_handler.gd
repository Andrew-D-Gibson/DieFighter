class_name AddAmountHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount += data.amount
