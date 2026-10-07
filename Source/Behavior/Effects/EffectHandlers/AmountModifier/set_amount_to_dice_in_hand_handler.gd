class_name SetAmountToDiceInHandHandler
extends EffectHandler

## The activator die has already left the hand by the time a chain runs, so
## this counts only what's still waiting to be played.


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not Globals.player:
		return

	context.running_amount = Globals.player.dice_manager.queue.size()
