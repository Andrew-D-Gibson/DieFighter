class_name Effect
extends Node2D

# A default amount for effects like damage/shields/etc.
# The default is ignored when it's 0
# This is also ignored for effects that don't need amounts of course
@export var amount: int = 0

func play(_effect_variables: EffectVariables) -> void:
	pass
