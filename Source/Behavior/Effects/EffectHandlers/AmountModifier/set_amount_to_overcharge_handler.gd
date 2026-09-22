class_name SetAmountToOverchargeHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not Globals.player:
		return

	context.running_amount = Globals.player.overcharge_amount()
