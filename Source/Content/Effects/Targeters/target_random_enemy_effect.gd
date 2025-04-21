class_name TargetRandomEnemyEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies().duplicate()
	
	if effect_variables.actor is Enemy:
		enemies.erase(effect_variables.actor)
		
	if len(enemies) == 0:
		effect_variables.targets = Array([])
		return
			
	effect_variables.targets = Array([enemies.pick_random()])
