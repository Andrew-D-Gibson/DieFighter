class_name ActivationResource
extends Resource

@export_category('Info')
@export var description: String

func criteria_satisfied(_die: Dice) -> bool:
	return true
