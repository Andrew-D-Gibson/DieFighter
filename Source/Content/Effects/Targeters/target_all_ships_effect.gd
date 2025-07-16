class_name TargetAllShipsEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets = Array([])
	
	# Add the player
	effect_variables.targets.append(Globals.player)
	
	# Add other ships
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	effect_variables.targets.append_array(enemies)
