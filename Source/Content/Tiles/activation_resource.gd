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
}

@export var type: ActivationType


# VALUE activation values
@export var acceptable_values: Array[int]


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

	ActivationType.SHIP_TARGETED: 
		func(_die: Dice) -> bool:
			if not Globals.targeting_computer:
				return false
				
			return Globals.targeting_computer.targeted_enemy != null,
			
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
		func(_die:Dice) -> bool:
			if not Globals.targeting_computer:
				return false
				
			if not Globals.targeting_computer.targeted_enemy:
				return false
			
			return Globals.targeting_computer.targeted_enemy.health.shields > 0,
			
	ActivationType.ENGINE_NOT_CHARGED:
		func(_die: Dice) -> bool:
			return Globals.player.engine_charge < Globals.player.max_engine_charge,
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
}


func criteria_satisfied(die: Dice) -> bool:
	return activation_functions[type].call(die)
	

func get_criteria_fail_text() -> String:
	return failed_activation_messages[type]
