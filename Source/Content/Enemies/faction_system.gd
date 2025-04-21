# First, let's create a FactionSystem class to handle faction relationships
class_name FactionSystem
extends RefCounted

## Handles faction relationships and determines valid targets
## Defines which factions can attack each other and under what conditions

enum Faction {
	PLAYER,
	PIRATE,
	CIVILIAN,
	SOLDIER
}

# Define which factions can attack each other
# Format: {attacker_faction: [valid_target_factions]}
const VALID_TARGETS = {
	Faction.PIRATE: [Faction.PLAYER, Faction.CIVILIAN, Faction.SOLDIER],
	Faction.SOLDIER: [Faction.PIRATE],
	Faction.CIVILIAN: [],  # Civilians don't attack anyone
	Faction.PLAYER: [Faction.PIRATE]  # Player can attack pirates
}

# Define faction attitudes towards each other
# Format: {faction: {target_faction: attitude}}
const FACTION_ATTITUDES = {
	Faction.PIRATE: {
		Faction.PIRATE: Enemy.Attitude.FRIENDLY,
		Faction.PLAYER: Enemy.Attitude.AGGRESSIVE,
		Faction.CIVILIAN: Enemy.Attitude.AGGRESSIVE,
		Faction.SOLDIER: Enemy.Attitude.AGGRESSIVE
	},
	Faction.SOLDIER: {
		Faction.PIRATE: Enemy.Attitude.AGGRESSIVE,
		Faction.PLAYER: Enemy.Attitude.FRIENDLY,
		Faction.CIVILIAN: Enemy.Attitude.FRIENDLY,
		Faction.SOLDIER: Enemy.Attitude.FRIENDLY
	},
	Faction.CIVILIAN: {
		Faction.PIRATE: Enemy.Attitude.AGGRESSIVE,
		Faction.PLAYER: Enemy.Attitude.FRIENDLY,
		Faction.CIVILIAN: Enemy.Attitude.FRIENDLY,
		Faction.SOLDIER: Enemy.Attitude.FRIENDLY
	}
}

## Checks if an attacker can target a specific faction
static func can_attack(attacker_faction: Faction, target_faction: Faction) -> bool:
	return target_faction in VALID_TARGETS.get(attacker_faction, [])

## Gets the attitude of one faction towards another
static func get_faction_attitude(faction: Faction, target_faction: Faction) -> Enemy.Attitude:
	return FACTION_ATTITUDES.get(faction, {}).get(target_faction, Enemy.Attitude.NEUTRAL)
