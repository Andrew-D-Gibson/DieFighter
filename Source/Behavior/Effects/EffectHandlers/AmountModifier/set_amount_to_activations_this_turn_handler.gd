class_name SetAmountToActivationsThisTurnHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, _engine: ScenarioEngine) -> void:
	if not Globals.tile_grid:
		return

	context.running_amount = Globals.tile_grid.activations_this_turn
