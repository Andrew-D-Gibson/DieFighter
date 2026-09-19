class_name MultiplyAmountHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = int(context.running_amount * data.multiplier)
