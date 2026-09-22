class_name SetAmountToMissingChargeHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not Globals.player:
		return

	context.running_amount = Globals.player.missing_charge()
