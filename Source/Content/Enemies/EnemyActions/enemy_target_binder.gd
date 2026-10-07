class_name EnemyTargetBinder
extends RefCounted
## Picks the ship each rolled slot acts on: the ally a Repair Beam mends, the
## civilian a raid hits.
##
## Done once, when the table is rolled, rather than when the die is spent, so
## the intent can name the ship before the player commits a die. A slot only
## binds once the whole roster has rolled, since who it can pick depends on
## everyone else.


## Binds every slot of every ship in [param ships] against [param roster].
static func bind(ships: Array[Enemy], roster: Array[Enemy]) -> void:
	for ship: Enemy in ships:
		if not is_instance_valid(ship):
			continue
		for slot: int in range(ship.turn_actions.size()):
			bind_slot(ship, slot, roster)


## Re-points every slot that was bound to [param departed], which has just
## left the board. The slot keeps its action: the player has been reading it.
## With nobody left to pick, it stays unbound, and its targeting step finds no
## one.
static func rebind_departed(departed: Enemy, roster: Array[Enemy]) -> void:
	for ship: Enemy in roster:
		if not is_instance_valid(ship) or ship == departed:
			continue
		for slot: int in range(ship.turn_actions.size()):
			var action: EnemyActionResource = ship.turn_actions[slot]
			if action and action.bound_target == departed:
				bind_slot(ship, slot, roster)


## Returns false when the slot needs a ship and none can be had.
static func bind_slot(ship: Enemy, slot: int, roster: Array[Enemy]) -> bool:
	var action: EnemyActionResource = ship.turn_actions[slot]
	if action == null:
		return true
	action.bound_target = null

	var candidates: Array[Enemy] = candidates_for(ship, action, roster)
	if candidates.is_empty():
		return action.get_binding() == EnemyActionResource.Binding.NONE

	action.bound_target = RNGManager.pick_random(RNGManager.Bucket.ENEMY_AI, candidates)
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
