class_name SpendShieldsEvent
extends EffectEvent
## A shield cost. [member amount] is the positive price.
##
## Not a negative ShieldEvent: that goes through Health.change_shields, which
## reads as the shields being hit (the hit sound and shake, "shields broken"
## at zero). Paying for a payoff with shields is a choice, not damage, so it
## sets the value directly. Like SpendEngineChargeEvent it refuses rather than
## underflowing; tiles gate affordability with SHIELDS_AT_LEAST before the die
## is consumed.


## amount is a price, not an output.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player) or amount <= 0:
		return

	var health: Health = Globals.player.health
	if health.shields < amount:
		push_warning(
			"SpendShieldsEvent: cost %d exceeds shields %d. The tile's "
			% [amount, health.shields]
			+ "SHIELDS_AT_LEAST threshold disagrees with its authored cost."
		)
		return

	health.shields -= amount
