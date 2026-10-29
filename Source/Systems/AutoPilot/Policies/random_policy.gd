class_name RandomPolicy
extends AutoPilotPolicy
## Plays wherever a die is accepted, with no thought for what happens next.
## The baseline every smarter policy is measured against, and the widest net
## for crashes and softlocks.

## How likely each kind of move is to be picked when it's available, before
## choosing uniformly within the kind. By kind first, because a busy fight
## offers a move per ship to retarget to, and those shouldn't crowd out
## placing dice. End Turn only lights once the hand is spent, so it wins
## over everything but salvage and shopping, which it competes with as an
## equal: a random player takes some offers and walks past others.
const _KIND_WEIGHTS: Dictionary[AutoPilotMove.Kind, float] = {
	AutoPilotMove.Kind.PLACE_DIE: 1.0,
	AutoPilotMove.Kind.TARGET: 0.25,
	AutoPilotMove.Kind.VIEW_MAP: 0.2,
	AutoPilotMove.Kind.VIEW_SYSTEMS: 0.2,
	AutoPilotMove.Kind.END_TURN: 1.0,
	AutoPilotMove.Kind.CLAIM: 2.0,
	AutoPilotMove.Kind.BUY: 0.5,
	AutoPilotMove.Kind.REPAIR: 0.5,
	# Rare: a random seller would strip its own grid at every station, and
	# the point is to exercise the path, not to lose every run to it.
	AutoPilotMove.Kind.SELL: 0.05,
	# Rare too: enough to exercise dragging tiles about between fights.
	AutoPilotMove.Kind.MOVE_TILE: 0.05,
}


## Chance a random player ends the turn early when it could keep its hand.
const _BANK_CHANCE: float = 0.25


func choose(moves: Array[AutoPilotMove], rng: RandomNumberGenerator) -> AutoPilotMove:
	var by_kind: Dictionary[AutoPilotMove.Kind, Array] = {}
	for move: AutoPilotMove in moves:
		if not by_kind.has(move.kind):
			by_kind[move.kind] = []
		by_kind[move.kind].append(move)

	# A ship that may keep its hand (the Outrigger) lights End Turn with dice
	# still in it. A random player sometimes banks them, mostly plays on.
	if by_kind.has(AutoPilotMove.Kind.END_TURN) and not AutoPilotMove.dice_in_hand().is_empty():
		if rng.randf() >= _BANK_CHANCE:
			by_kind.erase(AutoPilotMove.Kind.END_TURN)
	if by_kind.has(AutoPilotMove.Kind.END_TURN):
		var shopping: bool = by_kind.has(AutoPilotMove.Kind.CLAIM) or by_kind.has(AutoPilotMove.Kind.BUY)
		if not shopping:
			return by_kind[AutoPilotMove.Kind.END_TURN][0]
		for idle: AutoPilotMove.Kind in [AutoPilotMove.Kind.PLACE_DIE, AutoPilotMove.Kind.TARGET,
				AutoPilotMove.Kind.VIEW_MAP, AutoPilotMove.Kind.VIEW_SYSTEMS]:
			by_kind.erase(idle)

	# Kinds in enum order, so the draw doesn't depend on dictionary order.
	var kinds: Array[AutoPilotMove.Kind] = []
	var weights: PackedFloat32Array = []
	for kind: AutoPilotMove.Kind in AutoPilotMove.Kind.values():
		if by_kind.has(kind):
			kinds.append(kind)
			weights.append(_KIND_WEIGHTS.get(kind, 1.0))
	var options: Array = by_kind[kinds[rng.rand_weighted(weights)]]
	return options[rng.randi_range(0, options.size() - 1)]
