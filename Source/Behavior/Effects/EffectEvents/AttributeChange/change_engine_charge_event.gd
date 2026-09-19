class_name ChangeEngineChargeEvent
extends EffectEvent

func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return
		
	Globals.player.engine_charge += amount
