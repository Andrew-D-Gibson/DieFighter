class_name FleeEvent
extends EffectEvent


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor) or actor is not Enemy:
		return
	
	var enemy: Enemy = actor as Enemy
	enemy.dice_manager.give_away_dice()
	# Deaf to the scenario first, as in Enemy._on_death: enemy_left can fire
	# PIRATES_DEFEATED at once, and a ship still listening would react to it.
	enemy.disconnect_scenario_signals()

	Events.enemy_left.emit(enemy, enemy.scenario_state.faction)
	enemy.queue_free()
