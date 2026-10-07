class_name EnemyActionSituation
extends RefCounted
## What a ship can see of the board when it rolls its six intent slots.
##
## Built once per roll, so every gate and weight reads the same snapshot, and a
## test can describe a board without standing one up.

## The ship rolling. May be null in a test that only cares about the gates.
var ship: Enemy = null

## Whether the player can read the table being rolled. See
## GameStateManager.enemy_intents_visible().
var intents_visible: bool = true

## Living ships on the same side as [member ship], not counting it.
var allies: Array[Enemy] = []

## Living ships [member ship]'s faction preys on. Never the player.
var hostile_ships: Array[Enemy] = []

## How much of its hull [member ship] has left, 0 to 1.
var health_fraction: float = 1.0

## [member ship]'s attitude toward the player.
var attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE


static func for_ship(rolling_ship: Enemy, roster: Array[Enemy] = []) -> EnemyActionSituation:
	var situation := EnemyActionSituation.new()
	situation.ship = rolling_ship
	if Globals.state_manager:
		situation.intents_visible = Globals.state_manager.enemy_intents_visible()
	if roster.is_empty() and Globals.enemy_manager:
		roster = Globals.enemy_manager.get_alive_enemies()

	situation.allies = allies_of(rolling_ship, roster)
	situation.hostile_ships = hostile_ships_of(rolling_ship, roster)
	situation.health_fraction = hull_fraction(rolling_ship)
	if rolling_ship.scenario_state:
		situation.attitude = rolling_ship.scenario_state.attitude
	return situation


## Whether any ally is below [param fraction] of its hull.
func has_ally_below(fraction: float) -> bool:
	for ally: Enemy in allies:
		if hull_fraction(ally) < fraction:
			return true
	return false


static func allies_of(of_ship: Enemy, roster: Array[Enemy]) -> Array[Enemy]:
	return _others_where(of_ship, roster, FactionRelations.are_allied)


static func hostile_ships_of(of_ship: Enemy, roster: Array[Enemy]) -> Array[Enemy]:
	return _others_where(of_ship, roster, FactionRelations.are_hostile)


static func hull_fraction(of_ship: Enemy) -> float:
	if of_ship.health.max_health <= 0:
		return 1.0
	return float(of_ship.health.health) / float(of_ship.health.max_health)


## Living ships other than [param of_ship] whose faction passes
## [param relation] against its own.
static func _others_where(of_ship: Enemy, roster: Array[Enemy], relation: Callable) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if of_ship == null or of_ship.scenario_state == null:
		return out
	for other: Enemy in roster:
		if other == of_ship or not is_instance_valid(other) or other.scenario_state == null:
			continue
		if other.health.health <= 0:
			continue
		if relation.call(of_ship.scenario_state.faction, other.scenario_state.faction):
			out.append(other)
	return out
