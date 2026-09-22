class_name ChangeEngineChargeEvent
extends EffectEvent
## Moves the player's engine charge by [member amount].
##
## Clamps to max_engine_charge unless [member allow_overcharge] is set, even
## though Player's own ceiling is higher. That split is what keeps the redline
## deliberate: the ordinary Engine Charger tile topping a nearly-full drive off
## with a 6 must stop at the gate rather than spill into a band that costs hull
## every turn. Only ADD_OVERCHARGE opts in.

## Permit this change to push charge past max, into the redline band.
var allow_overcharge: bool = false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player):
		return

	var target: int = Globals.player.engine_charge + amount
	if not allow_overcharge:
		target = mini(target, Globals.player.max_engine_charge)

	Globals.player.engine_charge = target

	# Only an enemy taking charge counts as a drain. The player dumping their
	# own bar through Emergency Transfer or Overdraw Coil is a purchase, not a
	# theft, and shouldn't arm anything that retaliates.
	if amount < 0 and actor is Enemy:
		Events.engine_charge_drained.emit()
