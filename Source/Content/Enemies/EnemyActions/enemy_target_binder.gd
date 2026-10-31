class_name EnemyTargetBinder
extends RefCounted
## Picks the ship each rolled slot acts on: the ally a Repair Beam mends, the
## civilian a raid hits, the ally a Relay hands its die to.
##
## Done once, when the table is rolled, rather than when the die is spent, so
## the intent can name the ship before the player commits a die. A slot only
## binds once the whole roster has rolled, since who it can pick depends on
## everyone else. A binding is never re-pointed: if its ship leaves, the
## slot's action simply can't happen (EnemyActionResource.Outcome.BLOCKED),
## rather than landing on a ship the player never saw it aimed at.
##
## Relays are where this earns its keep. Think of every (ship, die face) as a
## node: a relay slot is an edge to the (ally, face) the die arrives as. Each
## node has at most one edge out, so "would this binding loop?" is just a walk
## forward from the ally it would point at. A relay is only ever bound to an
## ally that can't lead back to it, which keeps the whole graph loop-free by
## construction; when no ally qualifies, that one slot is rerolled into
## something that relays nothing. No retries, no dice rerolled in flight.
##
## A ship works with one partner a turn: every ally slot binds the same ally,
## every raid the same prey. The targeting computer draws an arc per bound
## ship, and a Tender spread over three escorts buried the formation in arcs
## the player had to untangle; "this turn it's guarding *that* one" reads at
## a glance, and gives the player a pair to break up. The first slot to bind
## picks the partner; a relay that can't reach it without looping is
## rerolled like one with no ally at all, rather than opening a second arc.


## Binds every slot of every ship in [param ships] against [param roster].
static func bind(ships: Array[Enemy], roster: Array[Enemy]) -> void:
	for ship: Enemy in ships:
		if not is_instance_valid(ship):
			continue
		var partners: Dictionary[EnemyActionResource.Binding, Enemy] = {}
		for slot: int in range(ship.turn_actions.size()):
			if bind_slot(ship, slot, roster, partners):
				continue
			if ship.turn_actions[slot].get_relay() == EnemyActionResource.Relay.NONE:
				continue
			# A relay with nobody it can safely feed: swap that one slot out.
			ship.reroll_slot_without_relays(slot, EnemyActionSituation.for_ship(ship, roster))
			bind_slot(ship, slot, roster, partners)


## Returns false when the slot needs a ship and none can be had.
## [param partners] maps each binding to the ship [param ship]'s earlier
## slots of that binding settled on this turn: the slot joins it, or picks it.
static func bind_slot(
	ship: Enemy,
	slot: int,
	roster: Array[Enemy],
	partners: Dictionary[EnemyActionResource.Binding, Enemy] = {}
) -> bool:
	var action: EnemyActionResource = ship.turn_actions[slot]
	if action == null:
		return true
	action.bound_target = null

	var binding: EnemyActionResource.Binding = action.get_binding()
	var candidates: Array[Enemy] = candidates_for(ship, action, roster)
	if partners.has(binding):
		candidates = candidates.filter(func(other: Enemy) -> bool: return other == partners[binding])
	if action.get_relay() != EnemyActionResource.Relay.NONE:
		var face: int = slot + 1
		candidates = candidates.filter(func(ally: Enemy) -> bool:
			return not would_loop(ship, face, ally, action.relay_face(face))
		)
	if candidates.is_empty():
		return binding == EnemyActionResource.Binding.NONE

	action.bound_target = RNGManager.pick_random(RNGManager.Bucket.ENEMY_AI, candidates)
	partners[binding] = action.bound_target
	return true


## The ships [param action] could be bound to.
static func candidates_for(ship: Enemy, action: EnemyActionResource, roster: Array[Enemy]) -> Array[Enemy]:
	match action.get_binding():
		EnemyActionResource.Binding.ALLY:
			return EnemyActionSituation.allies_of(ship, roster)
		EnemyActionResource.Binding.HOSTILE_SHIP:
			return EnemyActionSituation.hostile_ships_of(ship, roster)
	var none: Array[Enemy] = []
	return none


## Whether relaying the die on [param ship]'s [param face] slot to
## [param ally], where it lands as [param arrival_face], could ever bring a
## die back to that same slot.
static func would_loop(ship: Enemy, face: int, ally: Enemy, arrival_face: int) -> bool:
	var at_ship: Enemy = ally
	var at_face: int = arrival_face
	# Binding never lets the graph loop, so the walk always runs out. Coming
	# back to any node at all would mean that invariant broke; count it as a
	# loop rather than walk forever.
	var seen: Dictionary[String, bool] = {}
	while true:
		if at_ship == ship and at_face == face:
			return true
		var key: String = "%d:%d" % [at_ship.get_instance_id(), at_face]
		if seen.has(key):
			return true
		seen[key] = true
		var next: Array = next_hop(at_ship, at_face)
		if next.is_empty():
			return false
		at_ship = next[0]
		at_face = next[1]
	return true


## Where a die of [param face] goes next once [param ship] spends it, as
## [ship, face], or empty if it stops there.
static func next_hop(ship: Enemy, face: int) -> Array:
	if not is_instance_valid(ship) or face < 1 or face > ship.turn_actions.size():
		return []
	var action: EnemyActionResource = ship.turn_actions[face - 1]
	if action == null or action.get_relay() == EnemyActionResource.Relay.NONE:
		return []
	var ally: Enemy = action.bound_ship()
	if not is_instance_valid(ally) or ally.health.health <= 0:
		return []
	return [ally, action.relay_face(face)]
