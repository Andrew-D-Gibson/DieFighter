class_name ActivationResource
extends Resource

enum ActivationType {
	VALUE, 
	IN_COMBAT, 
	OTHER_SHIPS_EXIST,
	SHIP_TARGETED,
	ACTIVATOR_DIE_NOT_HOLOGRAPHIC,
}

@export var type: ActivationType


# VALUE activation values
@export var acceptable_values: Array[int]


var activation_functions: Dictionary[ActivationType, Callable] = {
	
	ActivationType.VALUE: 
		func(die: Dice): 
			return die.value in acceptable_values,
	
	ActivationType.IN_COMBAT: 
		func(_die: Dice): 
			return Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT,

	ActivationType.OTHER_SHIPS_EXIST: 
		func(_die: Dice): 
			return len(Globals.enemy_manager.enemies) > 0,

	ActivationType.SHIP_TARGETED: 
		func(_die: Dice):
			return Globals.targeting_computer.targeted_enemy != null,
			
	ActivationType.ACTIVATOR_DIE_NOT_HOLOGRAPHIC: 
		func(die: Dice):
			return not die.holographic
}


func criteria_satisfied(die: Dice) -> bool:
	return activation_functions[type].call(die)
