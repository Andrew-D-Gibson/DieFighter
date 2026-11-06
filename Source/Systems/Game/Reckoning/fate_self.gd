class_name FateSelf
extends RefCounted
## "You" (RECKONING_ENDINGS.md §4): what the hole made of the player, spawned
## once the Tally is spent. Nothing reaches it by accident. Every way a ship
## is picked without the player aiming (hit-everything and random targeting,
## a dead ship's dice, Plunder's thief, a delayed payload's next host, an
## ally's Raid) leaves it out through is_self(), and FateSelfWard turns away
## whatever still lands on it unaimed. The only way to destroy it is damage
## from a die spent while it's targeted.

## Marks the ship. Metadata rather than a field on Enemy: only the Reckoning
## ever makes one.
const _META: StringName = &"fate_self"


## Marks [param ship] as "You". It doesn't die like a ship: no kill-cam, no
## wreck, no salvage, no death sounds. Its presentation (FateSelfPresentation)
## tears it apart on Events.fate_self_destroyed instead.
static func mark(ship: Enemy) -> void:
	ship.set_meta(_META, true)
	if ship.health.death.is_connected(ship._on_death):
		ship.health.death.disconnect(ship._on_death)
	ship.health.death.connect(_fall.bind(ship))


## Enemy._on_death()'s bookkeeping without its show: the ship leaves the
## fight (ReckoningDirector hears it and ends the run), and any die it holds
## goes on as a dead ship's would. Not announced as destroyed: it isn't a
## kill for the collection, and it carries no statuses to clear.
static func _fall(ship: Enemy) -> void:
	if not is_instance_valid(ship):
		return
	ship.disconnect_scenario_signals()
	if ship.spending_tween and ship.spending_tween.is_running():
		ship.spending_tween.custom_step(1000.0)
	if ship.clickable_region:
		ship.clickable_region.set_deferred(&"disabled", true)
	Events.enemy_left.emit(ship, ship.scenario_state.faction)
	ship.dice_manager.give_away_dice(ship.spending_die if is_instance_valid(ship.spending_die) else null,
		EnemyDiceManager.Departure.DESTROYED)


## Whether [param node] is "You".
static func is_self(node: Variant) -> bool:
	return node is Node and is_instance_valid(node) and (node as Node).has_meta(_META)


## [param ships] without "You", for anything that picks ships by chance or
## all at once.
static func by_chance(ships: Array[Enemy]) -> Array[Enemy]:
	var reachable: Array[Enemy] = []
	for ship: Enemy in ships:
		if not is_self(ship):
			reachable.append(ship)
	return reachable


## Whether [param event] comes from a die the player spent while aiming at
## [param ship]: the one way to touch it.
static func is_aimed_at(event: EffectEvent, ship: Node) -> bool:
	if not is_instance_valid(event.activator_die) or event.activator_die is not Dice:
		return false
	if not is_instance_valid(Globals.targeting_computer):
		return false
	return Globals.targeting_computer.target_for(event.activator_die) == ship
