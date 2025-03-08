class_name ValueActivationResource
extends ActivationResource

@export_category('Behavior')
@export var acceptable_values: Array[int]

func criteria_satisfied(die: Dice) -> bool:
	return die.value in acceptable_values
