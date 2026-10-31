class_name SpendHullEvent
extends EffectEvent
## A hull cost. [member amount] is the positive price.
##
## It comes straight off the hull, past the shields: the shields are there to
## stop enemies, and a price they could soak would be no price for a ship
## that turtles. It is still a hull hit (Health.change_health), so the tiles
## that answer one (Spite Coil, Reactive Armor, Regenerative Brake) hear it.
## It isn't damage, though, so nothing that shapes or dodges a hit (Exposed,
## Phased, Double Damage, a death save) touches it.
##
## Like SpendShieldsEvent it refuses rather than kill: tiles gate it with
## HULL_AT_LEAST, one above the price, before the die is consumed. That check
## runs once, so an echoed second pass that would kill takes nothing and still
## pays out, quietly: echo's bonus, by design.


## amount is a price, not an output.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(Globals.player) or amount <= 0:
		return

	var health: Health = Globals.player.health
	if health.invulnerable:
		return
	if health.health <= amount:
		return

	health.change_health(-amount)
	DamageNumber.spawn(Globals.player, amount, Globals.red)
