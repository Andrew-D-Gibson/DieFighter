class_name ActivationResource
extends Resource

enum activation_type {VALUE, IN_COMBAT, SHIP_TARGETED}

@export var type: activation_type


# VALUE activation values
@export var acceptable_values: Array[int]


var activation_functions: Dictionary[activation_type, Callable] = {
	
	activation_type.VALUE: 
		func(die: Dice): 
			return die.value in acceptable_values,
	
	activation_type.IN_COMBAT: 
		func(_die: Dice): 
			return Globals.state_manager.state == GameStateManager.GameState.IN_COMBAT,

	activation_type.SHIP_TARGETED: 
		func(_die: Dice):
			return Globals.targeting_computer.targeted_enemy != null
}


func criteria_satisfied(die: Dice) -> bool:
	return activation_functions[type].call(die)
