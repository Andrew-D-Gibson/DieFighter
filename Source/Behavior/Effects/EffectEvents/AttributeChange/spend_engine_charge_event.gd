class_name SpendEngineChargeEvent
extends EffectEvent
## A charge cost. [member amount] is the positive price.
##
## Refuses rather than underflowing. ChangeEngineChargeEvent clamps a negative
## amount silently at zero, which is correct for an enemy drain but wrong for a
## price. Tiles gate affordability with the CHARGE_AT_LEAST activation check,
## which runs once, before the die is consumed. An echo then plays the chain
## twice past that one check, so a second pass the drive can't afford takes
## nothing and the payoff still lands: echo's bonus, by design (fun over
## balance). That's the expected way to get here, so it stays quiet.


## amount is a price, not an output.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return

	if Globals.player.engine_charge < amount:
		return

	Globals.player.engine_charge -= amount
