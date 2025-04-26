class_name MoveActorShipEffect
extends Effect

@export_range(0.0, 1.0) var new_position_proportion: float = 0.5

func play(effect_variables: EffectVariables) -> void:
	if effect_variables.actor == Globals.targeting_computer.targeted_enemy:
		Globals.targeting_computer.indicator_bob_tween.kill()
		Globals.targeting_computer.targeting_indicator.visible = false
	
	effect_variables.actor.graphics_manager.stop_bob_tween()
	effect_variables.actor.moving_in_world = true
	await Globals.enemy_manager.move_ship_to_point_on_path(
		effect_variables.actor,
		new_position_proportion
	)
	effect_variables.actor.moving_in_world = false
	effect_variables.actor.graphics_manager.start_bob_tween()
	
	if effect_variables.actor == Globals.targeting_computer.targeted_enemy:
		Globals.targeting_computer._move_indicator()
		
