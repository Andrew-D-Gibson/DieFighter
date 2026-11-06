class_name ShipUnlocks
extends RefCounted
## Which ships the player may fly. A ship with ShipResource.starts_locked is
## earned once, in any run, and kept for good (CollectionManager); until then
## its ship-select card shows a rumour of how to earn it. A ship still being
## built (coming_soon) is never pickable, earned or not.
##
## A ship is earned by an encounter (the Outrigger) or by the faces left on
## Fate's Die when a run ends (the Carousel, ShipUnlockDirector).
##
## The earning encounter (ShipResource.unlock_scenario) is dealt into the
## player's own runs only, like TileUnlocks: the Scenario Lab and the
## AutoPilot fly every ship and never meet it unless they ask for it.


## Whether the ship-select popup lets the player launch on [param ship].
static func is_pickable(ship: ShipResource) -> bool:
	return ship != null and not ship.coming_soon and not is_locked(ship)


## Still to be earned.
static func is_locked(ship: ShipResource) -> bool:
	return ship != null and ship.starts_locked and not CollectionManager.has_ship(String(ship.id))


## Earns [param id] for good (in the player's own runs; [param force] for the
## dev tools). True if it was locked until now.
static func unlock(id: StringName, force: bool = false) -> bool:
	return CollectionManager.record_ship(String(id), force)


## Whether [param die] earns [param ship]: it's earned by a face, and the die
## bears that face often enough. Says nothing of whether it's still locked.
static func die_earns(ship: ShipResource, die: FateDie) -> bool:
	return ship != null and die != null and ship.unlock_face != FateDie.Face.BLANK \
		and die.count(ship.unlock_face) >= ship.unlock_face_count


## The locked ships a run ending with [param die] earns.
static func earned_by_die(die: FateDie) -> Array[ShipResource]:
	var found: Array[ShipResource] = []
	for ship: ShipResource in ShipCatalog.all():
		if not ship.coming_soon and is_locked(ship) and die_earns(ship, die):
			found.append(ship)
	return found


## The locked ships that carving [param face] counts toward.
static func counted_by_face(face: FateDie.Face) -> Array[ShipResource]:
	var found: Array[ShipResource] = []
	if face == FateDie.Face.BLANK:
		return found
	for ship: ShipResource in ShipCatalog.all():
		if ship.unlock_face == face and not ship.coming_soon and is_locked(ship):
			found.append(ship)
	return found


## The encounters that can earn a ship, for sector [param sector_index] of
## one of the player's own runs: one per locked ship that is earned there.
static func scenarios_for_sector(sector_index: int) -> Array[ScenarioResource]:
	var found: Array[ScenarioResource] = []
	if not CollectionManager.is_recording():
		return found
	for ship: ShipResource in ShipCatalog.all():
		if ship.unlock_scenario and ship.unlock_sector == sector_index \
		and not ship.coming_soon and is_locked(ship):
			found.append(ship.unlock_scenario)
	return found
