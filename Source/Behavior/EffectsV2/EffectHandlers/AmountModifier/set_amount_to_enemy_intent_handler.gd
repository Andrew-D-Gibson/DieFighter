class_name SetAmountToEnemyIntentHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = context.enemy_intent_amount
