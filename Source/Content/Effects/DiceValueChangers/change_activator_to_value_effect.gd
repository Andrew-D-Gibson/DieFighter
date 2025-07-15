class_name ChangeActivatorToValueEffect
extends Effect

@export var new_value: int 

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("ChangeActivatorToValueEffect doesn't have an activator die!")
		return
		
	if not new_value:
		printerr("ChangeActivatorToValueEffect doesn't have a value set!")
		return
	
	await effect_variables.activator_die.reroll_with_tween(new_value)
