class_name BurnStatus
extends StatusModifier
## Each round, before the ship acts, it takes damage equal to its Burn, then
## the Burn drops by one. Five Burn is 5 + 4 + 3 + 2 + 1 over five rounds.

## Burn the ship loses each round, after it burns.
const LOST_PER_TICK: int = 1


static func rule_values() -> Dictionary:
	return {"lost": LOST_PER_TICK}


func on_status_tick() -> void:
	var ship: Node2D = host()
	if ship == null or _host_engine == null:
		return

	# On an enemy, the player lit it, so it is the player's damage: hitting a
	# neutral ship with it angers that ship like any other attack. On the
	# player it is the ship's own fire, like the redline's bleed. Either way no
	# tile or ship is the source, so it never cashes in Exposed or an Amplifier.
	var event: DamageEvent = DamageEvent.new()
	event.actor = Globals.player
	event.amount = stacks
	event.targets = [ship]
	_host_engine.queue_event(event)

	announce_triggered()
	consume(LOST_PER_TICK)


## The damage number already says how much it burned for; the orange flash
## and embers say why.
func get_trigger_text() -> String:
	return ""
