class_name SpendEngineChargeEvent
extends EffectEvent
## A charge cost. [member amount] is the positive price.
##
## Refuses rather than underflowing. ChangeEngineChargeEvent clamps a negative
## amount silently at zero, which is correct for an enemy drain but wrong for a
## price — it would let a tile fire its payoff for free. Tiles gate
## affordability with the CHARGE_AT_LEAST activation check, which runs before
## the die is consumed; reaching this check means that threshold and the
## authored cost disagree, so it is a bug worth hearing about rather than
## silently absorbing.


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return

	if Globals.player.engine_charge < amount:
		push_warning(
			"SpendEngineChargeEvent: cost %d exceeds charge %d. The tile's "
			% [amount, Globals.player.engine_charge]
			+ "CHARGE_AT_LEAST threshold disagrees with its authored cost."
		)
		return

	Globals.player.engine_charge -= amount
