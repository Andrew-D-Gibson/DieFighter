class_name FleeEvent
extends EffectEvent
## The acting ship leaves the fight, handing its dice to whoever is left (or
## home), and jumps away (Enemy.jump_away()).


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor) or actor is not Enemy:
		return
	
	var enemy: Enemy = actor as Enemy
	# Deaf to the scenario first, as in Enemy._on_death: enemy_left can fire
	# PIRATES_DEFEATED at once, and a ship still listening would react to it.
	enemy.disconnect_scenario_signals()

	Events.enemy_left.emit(enemy, enemy.scenario_state.faction)
	# After enemy_left, as in Enemy._on_death, so the heirs are the ships
	# still fighting once this one has gone (heirs_for_dice()). The die spent
	# on the Flee goes too, if the chain hasn't handed it on.
	enemy.dice_manager.give_away_dice(activator_die, EnemyDiceManager.Departure.FLEEING)
	# Only now, with the board settled, does it jump: the chain waits out the
	# jump so nothing resolves against a ship half gone.
	await Enemy.jump_away(enemy)
