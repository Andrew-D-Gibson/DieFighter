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

## Whether [member ship] already holds as many shields as its max hull, so
## actions that only shield it are no longer rolled. See at_shield_cap().
var shields_capped: bool = false

## The ids of the statuses on [member ship].
var statuses: Array[StringName] = []

## [member ship]'s attitude toward the player.
var attitude: Enemy.Attitude = Enemy.Attitude.AGGRESSIVE

## Whether [member ship]'s table must hold a face that hands its die on to a
## ship it fights (a Raid): it's on the player's side, and a ship it's hostile
## to is fighting the player. Otherwise it would be a safe place for every
## die, and the enemy, never handed one, would sit the turn out while the
## player charged their engines. See EnemyActionSelector._ensure_hand_off().
var owes_hand_off: bool = false

## Faces of the dice [member ship] kept itself last turn and still holds,
## lowest first and without repeats: the slots those dice will fire. Dice it
## was merely handed don't count.
var kept_faces: Array[int] = []

## Kept face -> the amount its die was loaded with (Enemy.loaded_amounts),
## for the faces whose loader had one. Two loaded dice on one face: the
## bigger.
var kept_amounts: Dictionary[int, int] = {}

## The most kinds of action the table may mix; 0 for no limit. Set from how
## deep into the run the player is, a little higher for a boss. See
## EnemyActionVariety.
var max_action_kinds: int = 0


static func for_ship(rolling_ship: Enemy, roster: Array[Enemy] = []) -> EnemyActionSituation:
	var situation := EnemyActionSituation.new()
	situation.ship = rolling_ship
	if Globals.state_manager:
		situation.intents_visible = Globals.state_manager.enemy_intents_visible()
		situation.max_action_kinds = Globals.state_manager.get_action_kinds_cap(is_boss(rolling_ship))
	if roster.is_empty() and Globals.enemy_manager:
		roster = Globals.enemy_manager.get_alive_enemies()

	situation.allies = allies_of(rolling_ship, roster)
	situation.hostile_ships = hostile_ships_of(rolling_ship, roster)
	situation.health_fraction = hull_fraction(rolling_ship)
	situation.shields_capped = at_shield_cap(rolling_ship)
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine:
		for status: StatusModifier in engine.statuses_on(rolling_ship):
			situation.statuses.append(status.status_id)
	if rolling_ship.scenario_state:
		situation.attitude = rolling_ship.scenario_state.attitude
	situation.owes_hand_off = sides_with_player(rolling_ship) \
		and situation.hostile_ships.any(func(other: Enemy) -> bool: return not sides_with_player(other))
	if rolling_ship.dice_manager:
		for die: Dice in rolling_ship.kept_dice:
			if not is_instance_valid(die) or die not in rolling_ship.dice_manager.queue:
				continue
			if die.value not in situation.kept_faces:
				situation.kept_faces.append(die.value)
			var loaded: int = rolling_ship.loaded_amounts.get(die, 0)
			if loaded > 0:
				situation.kept_amounts[die.value] = maxi(situation.kept_amounts.get(die.value, 0), loaded)
		situation.kept_faces.sort()
	return situation


## Whether [param of_ship] is on the player's side: anything not out to
## fight the player is, from a grateful civilian to a pirate busy elsewhere.
static func sides_with_player(of_ship: Enemy) -> bool:
	return of_ship.scenario_state != null \
		and of_ship.scenario_state.attitude != Enemy.Attitude.AGGRESSIVE


## Whether [param rolling_ship] is one of a boss fight's ships: every part of
## a gate boss fights under the boss faction.
static func is_boss(rolling_ship: Enemy) -> bool:
	return rolling_ship.scenario_state != null \
		and rolling_ship.scenario_state.faction == ScenarioManager.Faction.BOSS


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


## Whether any ally could still take shields: one below its shield cap.
func has_ally_under_shield_cap() -> bool:
	return allies.any(func(ally: Enemy) -> bool: return not at_shield_cap(ally))


## The soft cap on an enemy's shields: once a ship holds as many as its max
## hull, it stops rolling actions that only shield it, and its allies stop
## rolling them for it. Nothing clamps shields: a ship already over the cap,
## or one shielded by an action that does more besides (Relay),
## keeps every point. It only stops an endless pile, which is what turned
## Shield Burst and Aegis Link fights into stalemates.
static func at_shield_cap(of_ship: Enemy) -> bool:
	return of_ship.health.shields >= of_ship.health.max_health


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


## Whether [member ship] has the status [param status_id], or any status when
## it's empty.
func has_status(status_id: StringName = &"") -> bool:
	if status_id.is_empty():
		return not statuses.is_empty()
	return status_id in statuses
