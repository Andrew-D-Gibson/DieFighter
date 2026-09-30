class_name SetAmountToFeedDepthHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = context.feed_depth
