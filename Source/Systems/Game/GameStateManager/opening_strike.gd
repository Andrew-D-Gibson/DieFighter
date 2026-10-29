class_name OpeningStrike
extends RefCounted
## The ambusher's first shot of a new run, carrying the opening cutscene's
## attack straight into the fight. The ship flies in already holding one of
## the player's dice, the last of their hand, and fires its cannon with it
## before the player's first turn. The cannon hands the die on to its target
## as it always does, so the die drops into the player's hand: the first thing
## a run shows is the game's loop of a die used against you coming back to you.
## The player is dealt one die fewer to make room for it (see
## Player._arrive_with_hand()).
##
## GameStateManager starts a fresh run this much over the save's hull (see
## GameStateManager._owe_opening_strike()), so the shot leaves the player
## exactly where the save says a run begins.

## The shot it fires, whose chain hands the die back to the player. Loaded
## when it fires rather than preloaded: GameStateManager holds one of these,
## and a preload here would load the enemy-action scripts mid-way through
## their own preload cycle (EffectData -> StatusCatalog -> do_nothing.tres)
## and break them.
const ACTION_PATH: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres"
## Hull the shot takes.
const DAMAGE: int = 4
## A beat after the ship lands before it fires, so the shot reads as its
## first move rather than part of the fly-in.
const _WIND_UP_SECONDS: float = 0.5

var _damage: int = 0
var _shooter: Enemy
var _die: Dice


## Hands the first hostile ship the player's die, to fly in with. Call once
## the scenario's ships have spawned and before the hand is dealt. Null when
## there's no ship to fire.
static func arm(damage: int) -> OpeningStrike:
	var shooter: Enemy = _find_shooter()
	if damage <= 0 or shooter == null or not is_instance_valid(Globals.player):
		return null

	var strike: OpeningStrike = OpeningStrike.new()
	strike._damage = damage
	strike._shooter = shooter
	strike._die = Globals.player.dice_scene.instantiate()
	# Set before it enters the tree, so it neither rolls nor takes a die the
	# tutorial forced for the rest of the hand. Showing the hit lets the die
	# read as the shot.
	strike._die.value = clampi(damage, 1, 6)
	Globals.player.add_child(strike._die)
	shooter.dice_manager.add(strike._die)
	strike._die.global_position = strike._die.draggable.home_position
	return strike


## Fires the shot, and returns once the hit and everything it sets off have
## resolved and the die is back in the player's hand.
func play() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine or not _usable():
		_return_die()
		return

	await _shooter.get_tree().create_timer(_WIND_UP_SECONDS).timeout
	if not _usable() or engine.is_shut_down():
		_return_die()
		return

	var event: EnemyActionEvent = EnemyActionEvent.new()
	event.enemy = _shooter
	event.activator_die = _die
	event.die_value = _die.value
	event.action = _shot()
	# The shot isn't on the ship's intent table, so no row of it should light.
	event.pulses_intent = false
	engine.queue_event(event)
	if engine.currently_processing_queue:
		await engine.finished_processing_queue
	_return_die()


## The cannon's chain for [member _damage].
func _shot() -> EnemyActionResource:
	var action: EnemyActionResource = (load(ACTION_PATH) as EnemyActionResource).duplicate(true)
	action.intent_amount = _damage
	return action


func _usable() -> bool:
	return is_instance_valid(_shooter) and _shooter.health.health > 0 \
		and is_instance_valid(_die) and _die.host_queue == _shooter.dice_manager


## The die is the player's, so a shot that never fired (the ship died or the
## fight shut down first) still gives it back. After a shot it's already home.
func _return_die() -> void:
	var die: Dice = _die
	_die = null
	if not is_instance_valid(die) or not is_instance_valid(Globals.player):
		return
	if die.host_queue != Globals.player.dice_manager:
		Globals.player.dice_manager.add(die)


static func _find_shooter() -> Enemy:
	if not Globals.enemy_manager:
		return null
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.scenario_state and ship.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return ship
	return null
