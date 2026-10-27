class_name OpeningStrike
extends RefCounted
## The ambusher's first shot of a new run, carrying the opening cutscene's
## attack straight into the fight. The ship flies in already holding a die of
## its own, and once the player's hand is dealt it fires its cannon with it
## before the player's first turn. The die is the ship's, not the player's: it
## is spent on the shot, and the player's hand is never touched.
##
## GameStateManager starts a fresh run this much over the save's hull (see
## GameStateManager._owe_opening_strike()), so the shot leaves the player
## exactly where the save says a run begins.

## The shot it fires. Its own die-handling steps are stripped (see _shot()),
## so the ship's die isn't handed to the player. Loaded when it fires rather
## than preloaded: GameStateManager holds one of these, and a preload here
## would load the enemy-action scripts mid-way through their own preload
## cycle (EffectData -> StatusCatalog -> do_nothing.tres) and break them.
const ACTION_PATH: String = "res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres"
## Hull the shot takes.
const DAMAGE: int = 4
## A beat after the ship lands before it fires, so the shot reads as its
## first move rather than part of the fly-in.
const _WIND_UP_SECONDS: float = 0.5
const _SPENT_FADE_SECONDS: float = 0.25

var _damage: int = 0
var _shooter: Enemy
var _die: Dice


## Hands the first hostile ship its die, to fly in with. Call once the
## scenario's ships have spawned. Null when there's no ship to fire.
static func arm(damage: int) -> OpeningStrike:
	var shooter: Enemy = _find_shooter()
	if damage <= 0 or shooter == null or not is_instance_valid(Globals.player):
		return null

	var strike: OpeningStrike = OpeningStrike.new()
	strike._damage = damage
	strike._shooter = shooter
	strike._die = Globals.player.dice_scene.instantiate()
	# Set before it enters the tree, so it neither rolls nor takes a die the
	# tutorial forced for the player's hand.
	strike._die.value = clampi(damage, 1, 6)
	Globals.player.add_child(strike._die)
	# Not the player's die, so nothing that counts or rerolls theirs sees it.
	strike._die.remove_from_group(&"Dice")
	strike._die.draggable.dragging_allowed = false
	shooter.dice_manager.add(strike._die)
	strike._die.global_position = strike._die.draggable.home_position
	return strike


## Fires the shot, and returns once the hit and everything it sets off have
## resolved. The spent die fades away.
func play() -> void:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if not engine or not _usable():
		_discard_die()
		return

	await _shooter.get_tree().create_timer(_WIND_UP_SECONDS).timeout
	if not _usable() or engine.is_shut_down():
		_discard_die()
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
	_discard_die()


## The cannon's chain for [member _damage], minus the steps that would hand
## the die on.
func _shot() -> EnemyActionResource:
	var action: EnemyActionResource = (load(ACTION_PATH) as EnemyActionResource).duplicate(true)
	action.intent_amount = _damage
	var kept: Array[EffectData] = []
	for effect: EffectData in action.effect_chain.effects:
		if effect.category != EffectEnums.Category.DICE_CONTROL:
			kept.append(effect)
	action.effect_chain.effects = kept
	return action


func _usable() -> bool:
	return is_instance_valid(_shooter) and _shooter.health.health > 0 \
		and is_instance_valid(_die) and _die.host_queue == _shooter.dice_manager


func _discard_die() -> void:
	if not is_instance_valid(_die):
		return
	if _die.host_queue and _die in _die.host_queue.queue:
		_die.host_queue.remove(_die)
	var die: Dice = _die
	_die = null
	var fade: Tween = die.create_tween().set_parallel()
	fade.tween_property(die, ^"modulate:a", 0.0, _SPENT_FADE_SECONDS)
	fade.tween_property(die, ^"scale", Vector2.ONE * 0.4, _SPENT_FADE_SECONDS)
	fade.chain().tween_callback(die.queue_free)


static func _find_shooter() -> Enemy:
	if not Globals.enemy_manager:
		return null
	for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
		if ship.scenario_state and ship.scenario_state.attitude == Enemy.Attitude.AGGRESSIVE:
			return ship
	return null
