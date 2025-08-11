class_name TargetRandomShipEffect
extends Effect

func play(effect_variables: EffectVariables) -> void:
	var all_ships: Array = []
	
	# Add the player
	all_ships.append(Globals.player)
	
	# Add other ships
	var enemies: Array[Enemy] = Globals.enemy_manager.get_alive_enemies()
	all_ships.append_array(enemies)
	
	effect_variables.targets = Array([all_ships.pick_random()], TYPE_OBJECT, "Node", null)
