class_name WithdrawOffersEvent
extends EffectEvent
## Calls off whatever salvage is still floating, untaken: the price of a choice
## an encounter wants to cost something (Wreck Salvage's Rearguard guards the
## wreck, so firing on the guard forfeits it).


func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if is_instance_valid(Globals.reward_manager):
		Globals.reward_manager.withdraw_offers()
