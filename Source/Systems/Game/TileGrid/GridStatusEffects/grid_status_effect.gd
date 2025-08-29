class_name GridStatusEffect
extends Node2D

## A description of the info to show
@export var status_info: InfoResource = null

## Just like z-order, higher numbers are considered first
@export var status_effect_priority: int = 0

func clears_status_activation_criteria(activator_die: Dice = null) -> bool:
	return true
	
	
func manipulate_effect_variables(effect_variables: EffectVariables) -> EffectVariables:
	return effect_variables
	
	
func manipulate_effect_chain(effect_chain: EffectChain) -> EffectChain:
	return effect_chain
	
	
func show_info() -> void:
	if status_info:
		Events.show_info.emit(status_info)
		
	
func _exit_tree() -> void:
	# Remove itself from the tile_grid's dictionary
	if Globals.tile_grid.grid_status_effects.keys().has(self):
		Globals.tile_grid.grid_status_effects.erase(self)
