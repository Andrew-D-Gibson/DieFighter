class_name SetAmountToRandomHandler
extends EffectHandler


func apply(data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	# Drawn from a per-scenario bucket so a reloaded scenario rolls the same.
	context.running_amount = RNGManager.randi_range(
		RNGManager.Bucket.REWARDS,
		mini(data.range_min, data.range_max),
		maxi(data.range_min, data.range_max)
	)
