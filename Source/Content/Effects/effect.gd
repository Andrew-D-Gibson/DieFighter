class_name Effect
extends Resource

## A flag for the 'primary effect' like damage, shielding, etc.
## e.g. upgrades on things that 'double the effect' of something 
## will double this if true
@export var primary_effect: bool = false

## Each effect overrides this 'play' function to execute
func play(_effect_variables: EffectVariables) -> void:
	pass
