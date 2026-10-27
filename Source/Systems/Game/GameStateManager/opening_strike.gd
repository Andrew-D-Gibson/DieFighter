class_name OpeningStrike
extends RefCounted
## The ambusher's first shot of a new run, carrying the opening cutscene's
## attack straight into the fight: once the ship has landed it pulls the
## player's last die across, fires its cannon with it once, and the die comes
## back with the hit, so the hand the player starts with is the one they had.
##
## GameStateManager starts a fresh run this much over the save's hull (see
## GameStateManager.take_opening_strike()), so the shot leaves the player
## exactly where the save says a run begins.

## The shot it fires. Its chain hands the die back to the player.
const ACTION: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")
## Hull the shot takes.
const DAMAGE: int = 4
## A beat after the ship lands before it fires, so the shot reads as its
## first move rather than part of the fly-in.
const _WIND_UP_SECONDS: float = 0.5


## Fires [param damage] at the player from the first hostile ship, and returns
## once the hit and everything it sets off have resolved. Does nothing when
## there's no ship to fire or no die to take.
static func play(damage: int) -> void:
	var player: Player = Globals.player
	var engine: ScenarioEngine = ScenarioEngine.current()
	var shooter: Enemy = _shooter()
	var die: Dice = _last_real_die(player)
	if damage <= 0 or not engine or not shooter or not die:
		return

	var tree: SceneTree = player.get_tree()
	await tree.create_timer(_WIND_UP_SECONDS).timeout
	if not is_instance_valid(shooter) or not is_instance_valid(die) or engine.is_shut_down():
		return

	player.dice_manager.remove(die)
	shooter.dice_manager.add(die)
	TractorBeam.pull(die, shooter)
	await TractorBeam.wait_for_landings(tree)

	var action: EnemyActionResource = ACTION.duplicate(true)
	action.intent_amount = damage
	var event: EnemyActionEvent = EnemyActionEvent.new()
	event.enemy = shooter
	event.activator_die = die
	event.die_value = die.value
	event.action = action
	# The shot isn't on the ship's intent table, so no row of it should light.
	event.pulses_intent = false
	engine.queue_event(event)
	if engine.currently_processing_queue:
		await engine.finished_processing_queue


static func _shooter() -> Enemy:
	if not Globals.enemy_manager:
		return null
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.scenario_state and ship.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return ship
	return null


static func _last_real_die(player: Player) -> Dice:
	if not is_instance_valid(player):
		return null
	for i: int in range(player.dice_manager.queue.size() - 1, -1, -1):
		var die: Dice = player.dice_manager.queue[i]
		if is_instance_valid(die) and not die.holographic:
			return die
	return null
