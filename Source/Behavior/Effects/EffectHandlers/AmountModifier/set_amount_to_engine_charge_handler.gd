class_name SetAmountToEngineChargeHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	context.running_amount = Globals.player.engine_charge
