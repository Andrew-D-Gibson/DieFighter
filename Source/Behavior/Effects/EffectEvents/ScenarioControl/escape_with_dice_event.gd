class_name EscapeWithDiceEvent
extends EffectEvent
## Flee, but keep the loot. Where FleeEvent hands a ship's dice back out, this
## takes them off the board with it, and the player loses them for good: the
## same loss as jumping away from a ship that holds them.


func resolve(_engine: ScenarioEngine) -> void:
	if not is_instance_valid(actor) or actor is not Enemy:
		return
	var enemy: Enemy = actor as Enemy

	# EnemyActionEvent took the die being spent out of the queue before the
	# chain ran, so it rides along separately.
	var loot: Array[Dice] = []
	for die: Dice in enemy.dice_manager.queue:
		if is_instance_valid(die):
			loot.append(die)
	if is_instance_valid(activator_die) and activator_die is Dice and activator_die not in loot:
		loot.append(activator_die as Dice)

	if is_instance_valid(Globals.player):
		Globals.player.lose_dice_to(enemy, loot)

	# Deaf to the scenario first: enemy_left can fire PIRATES_DEFEATED at once,
	# and a ship still listening would react to its own exit.
	enemy.disconnect_scenario_signals()
	# Off the roster first, so the formation closes up behind it as it goes.
	Events.enemy_left.emit(enemy, enemy.scenario_state.faction)

	# The dice ride along: lose_dice_to() parked them on the hull, and they
	# go when it does.
	await Enemy.jump_away(enemy)
