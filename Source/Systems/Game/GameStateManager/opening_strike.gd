class_name OpeningStrike
extends RefCounted
## The ambusher's first shot of a new run, carrying the opening cutscene's
## attack straight into the fight. The ship flies in already holding one of
## the player's dice, the last of their hand, and fires its cannon with it
## before the player's first turn. The cannon hands the die on to its target
## as it always does, so the die drops into the player's hand: the first thing
## a run shows is the game's loop of a die used against you coming back to you.
##
## It owns the whole of that, start to finish, so nothing else has to keep
## its books:
##   owe()   A fresh run's save starts this much over its hull, so the shot
##           leaves the player exactly where the save says a run begins.
##   arm()   Once the ships have spawned, the ambusher takes the die. With no
##           ship to fire, the extra hull is taken back.
##   play()  Before the first turn, the shot. The hull is the save's after it.
## Until the shot lands, hull_owed() is what a checkpoint takes off the hull,
## so a Continue never replays the shot or keeps the extra. The hand is dealt
## one die fewer while holds_die() (see Player._arrive_with_hand()).

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

## What the shot takes, set when it's owed.
var _damage: int = 0
## Hull the run is carrying for the shot until it lands.
var _owed: int = 0
## Set once play() starts: the die is on its way back from then on.
var _fired: bool = false
var _shooter: Enemy
var _die: Dice


## Raises a fresh run's [param save] by the shot it's about to take, short of
## max hull, and returns the strike that owes it. Null if there's no room for
## any extra hull (a run starting at full).
static func owe(save: GameSaveResource) -> OpeningStrike:
	var owed: int = clampi(save.player_max_health - save.player_health, 0, DAMAGE)
	if owed <= 0:
		return null
	var strike: OpeningStrike = OpeningStrike.new()
	strike._damage = owed
	strike._owed = owed
	save.player_health += owed
	return strike


## Hands the first hostile ship the player's die, to fly in with. Call once
## the scenario's ships have spawned and before the hand is dealt. With no
## ship to fire, takes the extra hull back off [param save] and the player
## and returns false: there will be no shot.
func arm(save: GameSaveResource) -> bool:
	_shooter = _find_shooter()
	if _shooter == null or not is_instance_valid(Globals.player):
		_forgive(save)
		return false

	_die = Globals.player.dice_scene.instantiate()
	# Set before it enters the tree, so it neither rolls nor takes a die the
	# tutorial forced for the rest of the hand. Showing the hit lets the die
	# read as the shot.
	_die.value = clampi(_damage, 1, 6)
	Globals.player.add_child(_die)
	_shooter.dice_manager.add(_die)
	_die.global_position = _die.draggable.home_position
	return true


## Hull a checkpoint should take off the player's, so the save shows the hull
## as it will be once the shot lands. 0 once it has, or was never coming.
func hull_owed() -> int:
	return _owed


## True while the ambusher is flying in holding one of the player's dice,
## which the hand being dealt must leave room for.
func holds_die() -> bool:
	return not _fired and is_instance_valid(_die)


## Fires the shot, and returns once the hit and everything it sets off have
## resolved and the die is back in the player's hand. Only the first call
## does anything.
func play() -> void:
	if _fired:
		return
	_fired = true
	await _fire()
	# Whether it hit or never got off (the ship died first), the run carries
	# no more hull on its account.
	_owed = 0


func _fire() -> void:
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


## Takes back the extra hull for a shot that will never fire. Left owed, the
## run would keep it while every checkpoint subtracted it, down to a saved
## hull of zero or less for a player who'd since taken that much damage.
func _forgive(save: GameSaveResource) -> void:
	save.player_health -= _owed
	if is_instance_valid(Globals.player):
		Globals.player.health.health -= _owed
	_owed = 0


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
