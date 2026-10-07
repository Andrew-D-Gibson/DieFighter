class_name EnemyActionCondition
extends Resource
## A test against the board that an enemy action option can require, or scale
## its weight by. See EnemyActionOptionResource.conditions and
## EnemyActionWeightRule.
##
## Actions that need a ship to act on (an ally to repair, a civilian to raid)
## are gated on its existence automatically, read off their chain; these are
## for everything an author wants on top of that.

enum Type {
	## Another ship on this one's side is alive.
	ALLY_EXISTS,
	## A ship this one's faction preys on is alive.
	HOSTILE_SHIP_EXISTS,
	## An ally is below [member hull_fraction] of its hull.
	ALLY_HURT,
	## This ship is below [member hull_fraction] of its hull.
	SELF_HURT,
	## This ship's attitude toward the player is [member attitude].
	ATTITUDE_IS,
}

@export var type: Type = Type.ALLY_EXISTS

## Flips the result: "no ally is hurt", "not aggressive".
@export var invert: bool = false

## ALLY_HURT and SELF_HURT: the hull share a ship has to be below. 1.0 means
## any damage at all.
@export_range(0.0, 1.0, 0.05) var hull_fraction: float = 1.0

## ATTITUDE_IS: the attitude to match.
@export var attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE


func is_met(situation: EnemyActionSituation) -> bool:
	return _test(situation) != invert


func _test(situation: EnemyActionSituation) -> bool:
	match type:
		Type.ALLY_EXISTS:
			return not situation.allies.is_empty()
		Type.HOSTILE_SHIP_EXISTS:
			return not situation.hostile_ships.is_empty()
		Type.ALLY_HURT:
			return situation.has_ally_below(hull_fraction)
		Type.SELF_HURT:
			return situation.health_fraction < hull_fraction
		Type.ATTITUDE_IS:
			return situation.attitude == attitude
	return false
