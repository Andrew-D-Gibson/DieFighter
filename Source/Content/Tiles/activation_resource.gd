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
	## Another countdown tile (TileResource.countdown) is on the grid. For a
	## tile that works the other countdowns: with none it would eat the die.
	OTHER_COUNTDOWN_ON_GRID,
	## A twin-dice tile (Pair Lock): while it holds a die, it takes only a die
	## of the same face. With nothing held it takes any die.
	MATCHES_HELD_DIE,
	## A twin-dice tile (Lucky Seven): while it holds a die, it takes only a
	## die that adds up to [member threshold] with it. With nothing held it
	## takes any die.
	SUMS_WITH_HELD_DIE,
	## The ship this die was dropped against carries a status: any status, or
	## the one named in [member data_key]. For a tile that works the statuses
	## there (Status Catalyst any, Flashpoint "burn"): with none it would eat
	## the die.
	TARGETED_SHIP_HAS_STATUS,
	## The player has [member threshold] hull or more. Gates tiles that spend
	## hull (SPEND_HULL): set it one above the cost, so paying never kills.
	HULL_AT_LEAST,
	## The ship this die was dropped against holds a die showing more than
	## [member threshold]. For a tile that works the dice a ship holds (Cryo
	## Lance turns its highest to a 1): with nothing to change it would eat
	## the die.
	TARGETED_SHIP_HOLDS_DIE_ABOVE,
	## The player's evasion (EvasionModifier) is below its cap. For a tile
	## that adds evasion (Juke Thrusters): at the cap it would eat the die.
	EVASION_BELOW_CAP,
	## The player carries a harmful status (anything but Phased). For a tile
	## that moves the player's statuses away (Countermeasures): with none it
	## would eat the die.
	PLAYER_HAS_HARMFUL_STATUS,
}

@export var type: ActivationType


# VALUE activation values
@export var acceptable_values: Array[int]

# CHARGE_AT_LEAST / DICE_OWNED_AT_MOST / SHIELDS_AT_LEAST / TILE_DATA_AT_LEAST / HULL_AT_LEAST activation values
@export var threshold: int = 0

# TILE_DATA_AT_LEAST: the tile data entry to read. TARGETED_SHIP_HAS_STATUS:
# a status id to require (empty = any status).
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

	ActivationType.TARGETED_SHIP_HAS_STATUS:
		func(die: Dice) -> bool:
			if not Globals.targeting_computer:
				return false
			var target: Enemy = Globals.targeting_computer.target_for(die)
			var engine: ScenarioEngine = ScenarioEngine.current()
			if not target or not engine:
				return false
			if data_key.is_empty():
				return not engine.statuses_on(target).is_empty()
			return engine.find_status(target, StringName(data_key)) != null,

	ActivationType.HULL_AT_LEAST:
		func(_die: Dice) -> bool:
			if not Globals.player:
				return false

			return Globals.player.health.health >= threshold,

	ActivationType.TARGETED_SHIP_HOLDS_DIE_ABOVE:
		func(die: Dice) -> bool:
			if not Globals.targeting_computer:
				return false
			var target: Enemy = Globals.targeting_computer.target_for(die)
			if not target or not target.dice_manager:
				return false
			for held: Dice in target.dice_manager.queue:
				if is_instance_valid(held) and held != die and held.value > threshold:
					return true
			return false,

	ActivationType.EVASION_BELOW_CAP:
		func(_die: Dice) -> bool:
			var evasion: EvasionModifier = EvasionModifier.find(ScenarioEngine.current())
			return evasion != null and evasion.chance_percent() < EvasionModifier.MAX_PERCENT,

	ActivationType.PLAYER_HAS_HARMFUL_STATUS:
		func(_die: Dice) -> bool:
			return TransferStatusesEvent.has_any(ScenarioEngine.current(), Globals.player),
}


## Why each check turned a die away, as translation keys (the popup's text
## comes from get_criteria_fail_text()).
var failed_activation_messages: Dictionary[ActivationType, String] = {
	
	ActivationType.REQUIRES_ACTIVATOR_DIE: 
		"ERROR_REQUIRES_DIE",
			
	ActivationType.VALUE: 
		"ERROR_REQUIRES_VALUE",
	
	ActivationType.IN_COMBAT: 
		"ERROR_MUST_BE_IN_COMBAT",
		
	ActivationType.OTHER_SHIPS_EXIST: 
		"ERROR_NEEDS_OTHER_SHIPS",

	ActivationType.SHIP_TARGETED: 
		"ERROR_NO_TARGET",
			
	ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC: 
		"ERROR_NOT_WITH_HOLOGRAM",
			
	ActivationType.CANT_BE_ACTIVATED_WITH_DIE:
		"ERROR_NOT_WITH_DIE",
			
	ActivationType.TARGETED_SHIP_HAS_SHIELDS:
		"ERROR_TARGET_UNSHIELDED",
		
	ActivationType.ENGINE_NOT_CHARGED:
		"ERROR_ENGINE_FULL",
		
	ActivationType.ENGINE_CHARGED:
		"ERROR_ENGINE_EMPTY",
		
	ActivationType.CHARGE_AT_LEAST:
		"ERROR_LOW_CHARGE",
		
	ActivationType.OVERCHARGED:
		"ERROR_NOT_OVERCHARGED",

	ActivationType.DICE_OWNED_AT_MOST:
		"ERROR_TOO_MANY_DICE",

	ActivationType.SHIELDS_AT_LEAST:
		"ERROR_LOW_SHIELDS",

	ActivationType.TILE_DATA_AT_LEAST:
		"ERROR_NOT_READY",

	ActivationType.OTHER_COUNTDOWN_ON_GRID:
		"ERROR_NO_COUNTDOWNS",

	ActivationType.MATCHES_HELD_DIE:
		"ERROR_NOT_A_PAIR",

	ActivationType.SUMS_WITH_HELD_DIE:
		"ERROR_WRONG_SUM",

	ActivationType.TARGETED_SHIP_HAS_STATUS:
		"ERROR_TARGET_NO_STATUS",

	ActivationType.HULL_AT_LEAST:
		"ERROR_LOW_HULL",

	ActivationType.TARGETED_SHIP_HOLDS_DIE_ABOVE:
		"ERROR_TARGET_NO_BIG_DIE",

	ActivationType.EVASION_BELOW_CAP:
		"ERROR_EVASION_MAXED",

	ActivationType.PLAYER_HAS_HARMFUL_STATUS:
		"ERROR_NO_STATUS_ON_YOU",
}


## [param tile] is the tile asking, for checks that read the tile itself.
func criteria_satisfied(die: Dice, tile: Tile = null) -> bool:
	if type == ActivationType.TILE_DATA_AT_LEAST:
		return tile != null and int(tile.effect_data.get(data_key, 0)) >= threshold
	if type == ActivationType.OTHER_COUNTDOWN_ON_GRID:
		return not TileCountdown.others_on_grid(tile).is_empty()
	if type == ActivationType.MATCHES_HELD_DIE or type == ActivationType.SUMS_WITH_HELD_DIE:
		var held: Dice = tile.get_held_die(die) if tile else null
		return held == null or die == null or pairs_with(die.value, held.value)
	return activation_functions[type].call(die)


## Whether a die showing [param face] pairs with a held die showing
## [param held_face] under a held-die check (MATCHES_HELD_DIE,
## SUMS_WITH_HELD_DIE). Any other check pairs with anything. Takes faces so
## the AutoPilot can ask about a die it's only imagining.
func pairs_with(face: int, held_face: int) -> bool:
	match type:
		ActivationType.MATCHES_HELD_DIE:
			return face == held_face
		ActivationType.SUMS_WITH_HELD_DIE:
			return face + held_face == threshold
	return true


func get_criteria_fail_text() -> String:
	var text: String = TranslationServer.translate(failed_activation_messages[type])
	if type == ActivationType.SUMS_WITH_HELD_DIE:
		text = text.format({"total": threshold})
	elif type == ActivationType.TARGETED_SHIP_HAS_STATUS and not data_key.is_empty():
		text = TranslationServer.translate("ERROR_TARGET_LACKS_STATUS").format({"status": data_key.to_upper()})
	return text
