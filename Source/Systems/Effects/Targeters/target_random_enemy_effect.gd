extends Effect

func play(effect_variables: EffectVariables) -> void:
	var random_enemy: Enemy = Globals.enemy_manager.enemies.pick_random()
	effect_variables.targets = Array([random_enemy])
