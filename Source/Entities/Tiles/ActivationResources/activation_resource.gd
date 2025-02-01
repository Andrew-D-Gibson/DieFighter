class_name ActivationResource
extends Resource

@export_category('Info')
@export var description: String

@export_category('Graphics')
@export var activation_texture: Texture2D

@export_category('Behavior')
@export var acceptable_values: Array[int]


func criteria_satisfied(die: Dice) -> bool:
	return die.value in acceptable_values
