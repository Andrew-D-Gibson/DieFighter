class_name ChangeActivatorValueEffect
extends Effect

@export var new_value: int 
@export var offset_from_original_value: bool = false

func play(effect_variables: EffectVariables) -> void:
	if not effect_variables.activator_die:
		printerr("ChangeActivatorToValueEffect doesn't have an activator die!")
		return
		
	if not new_value:
		printerr("ChangeActivatorToValueEffect doesn't have a value set!")
		return
	
	if offset_from_original_value:
		await effect_variables.activator_die.reroll_with_tween(
			effect_variables.activator_die.value + new_value
		)
	else:
		await effect_variables.activator_die.reroll_with_tween(
			new_value
		)
