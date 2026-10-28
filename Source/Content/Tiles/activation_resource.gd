class_name ActivationResource
extends Resource

enum ActivationType {
	REQUIRES_ACTIVATOR_DIE,
	VALUE, 
	IN_COMBAT, 
	OTHER_SHIPS_EXIST,
	SHIP_TARGETED,
	ACTIVATOR_DIE_NOT_HOLOGRAPHIC,
	CANT_BE_ACTIVATED_WITH_DIE,
	TARGETED_SHIP_HAS_SHIELDS,
	ENGINE_NOT_CHARGED,
	ENGINE_CHARGED,
	## The player can afford [member threshold] engine charge. Runs before the
	## die is consumed, so a tile that spends charge refuses cleanly and hands
	## the die back instead of firing for free.
	CHARGE_AT_LEAST,
	## The drive is sitting above max — in the redline band.
	OVERCHARGED,
	## The player owns [member threshold] dice or fewer, holograms included.
	DICE_OWNED_AT_MOST,
	## The player has [member threshold] shields or more. Gates tiles that
	## spend or cash in shields, so they refuse rather than fire for nothing.
	SHIELDS_AT_LEAST,
	## The tile's own effect_data[[member data_key]] is [member threshold] or
	## more. For a tile whose payoff is a count it builds up (Slingshot's ring
	## steps): it refuses a die rather than fire for nothing.
	TILE_DATA_AT_LEAST,
}

@export var type: ActivationType


# VALUE activation values
@export var acceptable_values: Array[int]

# CHARGE_AT_LEAST / DICE_OWNED_AT_MOST / SHIELDS_AT_LEAST / TILE_DATA_AT_LEAST activation values
@export var threshold: int = 0

# TILE_DATA_AT_LEAST: the tile data entry to read.
@export var data_key: String = ""


var activation_functions: Dictionary[ActivationType, Callable] = {
	
	ActivationType.REQUIRES_ACTIVATOR_DIE: 
		func(die: Dice) -> bool: 
			return die != null,
			
	ActivationType.VALUE: 
		func(die: Dice) -> bool: 
			if not die:
				# We're being activated without a die
				return true
			return die.value in acceptable_values,
	
	ActivationType.IN_COMBAT: 
		func(_die: Dice) -> bool: 
			if not Globals.state_manager:
				return false
				
			return Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT,

	ActivationType.OTHER_SHIPS_EXIST: 
		func(_die: Dice) -> bool:
			if not Globals.enemy_manager:
				return false
				
			return len(Globals.enemy_manager.enemies) > 0,

	# The two targeting checks ask about the ship this die was dropped
	# against, the same one TARGET_WITH_TARGETING_COMPUTER will hit.
	ActivationType.SHIP_TARGETED: 
		func(die: Dice) -> bool:
			if not Globals.targeting_computer:
				return false
				
			return Globals.targeting_computer.target_for(die) != null,
			
	ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC: 
		func(die: Dice) -> bool:
			if not die:
				# We're being activated without a die,
				# so it's technically not holographic 
				return true
			return not die.holographic,
			
	ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
		func(die: Dice) -> bool:
			return not die,
			
	ActivationType.TARGETED_SHIP_HAS_SHIELDS:
		func(die: Dice) -> bool:
			if not Globals.targeting_computer:
				return false
				
			var target: Enemy = Globals.targeting_computer.target_for(die)
			if not target:
				return false
			
			return target.health.shields > 0,
			
	ActivationType.ENGINE_NOT_CHARGED:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return not Globals.player.is_engine_charged(),
			
	ActivationType.ENGINE_CHARGED:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.is_engine_charged(),
			
	ActivationType.CHARGE_AT_LEAST:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.can_afford_charge(threshold),
			
	ActivationType.OVERCHARGED:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.is_overcharged(),

	ActivationType.DICE_OWNED_AT_MOST:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.dice_owned() <= threshold,

	ActivationType.SHIELDS_AT_LEAST:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.health.shields >= threshold,
}


var failed_activation_messages: Dictionary[ActivationType, String] = {
	
	ActivationType.REQUIRES_ACTIVATOR_DIE: 
		"REQUIRES DIE",
			
	ActivationType.VALUE: 
		"REQUIRES CORRECT VALUE DIE",
	
	ActivationType.IN_COMBAT: 
		"MUST BE IN COMBAT",
		
	ActivationType.OTHER_SHIPS_EXIST: 
		"OTHER SHIPS MUST BE PRESENT",

	ActivationType.SHIP_TARGETED: 
		"NO VALID TARGET IN COMPUTER",
			
	ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC: 
		"CAN'T BE ACTIVATED WITH HOLOGRAPHIC DIE",
			
	ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
		"CAN'T BE ACTIVATED WITH DIE",
			
	ActivationType.TARGETED_SHIP_HAS_SHIELDS:
		"TARGETED SHIP HAS NO SHIELDS",
		
	ActivationType.ENGINE_NOT_CHARGED:
		"ENGINE IS FULLY CHARGED",
		
	ActivationType.ENGINE_CHARGED:
		"ENGINE IS NOT CHARGED",
		
	ActivationType.CHARGE_AT_LEAST:
		"NOT ENOUGH ENGINE CHARGE",
		
	ActivationType.OVERCHARGED:
		"ENGINE IS NOT OVERCHARGED",

	ActivationType.DICE_OWNED_AT_MOST:
		"TOO MANY DICE",

	ActivationType.SHIELDS_AT_LEAST:
		"NOT ENOUGH SHIELDS",

	ActivationType.TILE_DATA_AT_LEAST:
		"NOT READY",
}


## [param tile] is the tile asking, for checks that read the tile itself.
func criteria_satisfied(die: Dice, tile: Tile = null) -> bool:
	if type == ActivationType.TILE_DATA_AT_LEAST:
		return tile != null and int(tile.effect_data.get(data_key, 0)) >= threshold
	return activation_functions[type].call(die)
	

func get_criteria_fail_text() -> String:
	return failed_activation_messages[type]
