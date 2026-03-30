class_name TargetAllOtherShipsEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets.clear()
	
	# Add the player
	effect_variables.targets = [Globals.player]
	
	# Add other ships
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	effect_variables.targets.append_array(enemies)
	
	# Remove whoever is acting
	if effect_variables.actor in effect_variables.targets:
		effect_variables.targets.erase(
			effect_variables.actor
		)
	
