class_name FactionRelations
extends RefCounted
## Who fights alongside whom, and who preys on whom, among the ships that
## aren't the player. Enemy actions read this to pick an ally to repair or
## feed, or a ship to raid.
##
## How a ship feels about the *player* is its attitude, not its faction; this
## table is only about ships and each other. Anything finer (a pirate that
## won't raid while it's grateful) belongs on the action's authored
## conditions, not here.

## Factions that crew the same side. Every faction is also allied to itself.
const _ALLIED: Array[Array] = [
	[ScenarioManager.Faction.PIRATE, ScenarioManager.Faction.BOSS],
]

## Pairs that attack each other when given a die to do it with.
const _HOSTILE: Array[Array] = [
	[ScenarioManager.Faction.PIRATE, ScenarioManager.Faction.CIVILIAN],
	[ScenarioManager.Faction.BOSS, ScenarioManager.Faction.CIVILIAN],
]


static func are_allied(a: ScenarioManager.Faction, b: ScenarioManager.Faction) -> bool:
	return a == b or _pair_listed(_ALLIED, a, b)


static func are_hostile(a: ScenarioManager.Faction, b: ScenarioManager.Faction) -> bool:
	return _pair_listed(_HOSTILE, a, b)


static func _pair_listed(pairs: Array[Array], a: ScenarioManager.Faction, b: ScenarioManager.Faction) -> bool:
	for pair: Array in pairs:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false
