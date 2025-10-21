class_name JumpEffect
extends Effect

@export var amount: int = 0
@export var inherit_die_amount: bool = true
@export var jumping_right: bool = true


func play(effect_variables: EffectVariables) -> void:
	if inherit_die_amount and effect_variables.activator_die:
		effect_variables.base_amount = effect_variables.activator_die.value
	elif amount != 0:
		effect_variables.base_amount = amount
	
	# Calculate final damage after all modifiers
	var final_amount = effect_variables.calculate_final_amount()
	
	if not jumping_right:
		final_amount *= -1
	
	var current_scenario_index: int = Globals.map.current_scenario_index
	var desired_scenario_index: int = current_scenario_index + final_amount
	
	# Bound the target scenarios to within the map
	# e.g. moving "off the map" just moves you to the farthest possible sector
	if desired_scenario_index < 0:
		desired_scenario_index = 0
	elif desired_scenario_index >= len(Globals.map.scenario_list):
		desired_scenario_index = len(Globals.map.scenario_list) - 1
	
	if not Globals.map.is_valid_destination(desired_scenario_index):
		if effect_variables.activator_die:
			Globals.player.dice_manager.add(effect_variables.activator_die, true, false)
			
		if not effect_variables.effect_source:
			return
		Events.error_text_popup.emit("INVALID DESTINATION", effect_variables.effect_source.global_position)
		
		return

	Globals.map.jump(desired_scenario_index)
