class_name SetAmountToDiceInPlayHandler
extends EffectHandler
## See Player.dice_in_play(): what "per die in play" counts.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not Globals.player:
		return

	context.running_amount = Globals.player.dice_in_play()
