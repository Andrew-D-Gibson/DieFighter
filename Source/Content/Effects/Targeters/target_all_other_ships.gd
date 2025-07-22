class_name TargetAllOtherShipsEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	effect_variables.targets = Array([])
	
	# Add other ships
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	effect_variables.targets.append_array(enemies)
