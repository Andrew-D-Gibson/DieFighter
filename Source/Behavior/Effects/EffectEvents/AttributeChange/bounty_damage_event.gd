class_name BountyDamageEvent
extends DamageEvent
## A hit with a price on the target's head (Bounty Scanner): each target this
## very hit destroys pays [member bounty] credits, which float off the wreck
## to the money counter like any payout and land on the balance on arrival.
##
## Only this hit is credited: a target alive before it and dead after it. A
## ship finished off by something else (a Burn tick, another tile, its own
## overload) pays nothing, and neither does one that flees. Only a warship
## carries a bounty: a civilian (merchant, repair dock, transport) never
## does, even angry, and a launched fighter (no reward of its own) doesn't
## either, so a Carrier can't be farmed.
##
## Being a DamageEvent, the hit is grown and shrunk like any other (an
## Amplifier, Weakened, Exposed); the bounty is not.

const _MONEY_PARTICLE_SCENE: PackedScene = preload("res://Source/Systems/Game/MoneyParticles/money_particle.tscn")

## Credits per ship destroyed.
var bounty: int = 0
## What the hit paid out, once resolved.
var paid: int = 0
## Where the coins are parented; unset, the RewardManager (as a destroyed
## ship's drop is), or failing that the wreck's own parent.
var coin_parent: Node = null


func resolve(engine: ScenarioEngine) -> void:
	var alive: Array[Enemy] = []
	for target: Node in targets:
		if target is Enemy and is_instance_valid(target) and not (target as Enemy).health.is_dead \
				and (target as Enemy).health.health > 0:
			alive.append(target as Enemy)
	super(engine)
	if bounty <= 0:
		return
	for ship: Enemy in alive:
		if is_instance_valid(ship) and ship.health.health <= 0 and carries_bounty(ship):
			_pay(ship)


## Whether destroying [param ship] pays a bounty: a hostile warship that
## carries a reward of its own.
static func carries_bounty(ship: Enemy) -> bool:
	if not is_instance_valid(ship) or ship.reward_resource == null or ship.scenario_state == null:
		return false
	return ship.scenario_state.faction != ScenarioManager.Faction.CIVILIAN


func _pay(ship: Enemy) -> void:
	paid += bounty
	# Parented away from the wreck, so the coins outlive it.
	var parent: Node = coin_parent
	if not is_instance_valid(parent):
		parent = Globals.reward_manager if is_instance_valid(Globals.reward_manager) \
			else ship.get_parent()
	MoneyParticle.spawn_payout(parent, ship.global_position, bounty, _MONEY_PARTICLE_SCENE)
