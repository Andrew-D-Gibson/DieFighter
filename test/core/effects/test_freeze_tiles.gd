extends "res://test/helpers/die_fighter_test.gd"
## The tiles that work an enemy's dice and intents. Cryo Lance turns the
## highest die the target holds to a 1; Counter-Battery silences the target's
## intent for the face it hands over. Played whole through
## TileActivationEvent, so the use budget and the activation checks run as in
## a game; the engine records instead of resolving, and the events that move
## or change dice are resolved by hand so the dice really change.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Ships := preload("res://test/helpers/ships.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")
const DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy
var player: Player


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	Globals.player = player
	enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_resource = INTERCEPTOR
	enemy.scenario_state = ScenarioShipState.new()
	# A foe, so its intents read and the AutoPilot can value them.
	enemy.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	add_child_autofree(enemy)
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy] as Array[Enemy]
	Globals.enemy_manager = roster
	Globals.tile_grid = autofree(TileGrid.new())
	var state: GameStateManager = autofree(GameStateManager.new())
	state.state = GameStateManager.GameState.IN_COMBAT
	Globals.state_manager = state


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _tile(tile_id: String) -> Tile:
	var tile: Tile = TILE_SCENE.instantiate()
	tile.tile_resource = load(TILES % tile_id)
	add_child_autofree(tile)
	return tile


## A die in the player's hand.
func _die(face: int) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	player.dice_manager.add(die)
	return die


## A die the enemy is already holding.
func _held(face: int) -> Dice:
	var die: Dice = _die(face)
	enemy.dice_manager.add(die)
	TractorBeam.release(die)
	return die


## Drops [param face] on [param tile] and plays it through, resolving the
## events that change or hand over dice. Returns the events it made.
func _drop(tile: Tile, face: int) -> Array[EffectEvent]:
	var die: Dice = _die(face)
	if not tile.activation_refusal(die).is_empty():
		return [] as Array[EffectEvent]
	tile.dice_queue.add(die, true, false)
	var event := TileActivationEvent.new()
	event.tile = tile
	event.activator_die = die
	event.die_value = die.value
	engine.injected.clear()
	await event.resolve(engine)
	var made: Array[EffectEvent] = engine.injected.duplicate()
	var speed: float = Globals.animation_speed
	Globals.animation_speed = 50.0
	for each: EffectEvent in made:
		if each is ChangeHeldDiceEvent or each is GiveDieToTargetEvent or each is SilenceFaceEvent:
			await each.resolve(engine)
		if each is GiveDieToTargetEvent:
			TractorBeam.release(each.activator_die)
			await get_tree().process_frame
	Globals.animation_speed = speed
	return made


func _faces(hand: DiceQueue) -> Array[int]:
	var out: Array[int] = []
	for die: Dice in hand.queue:
		out.append(die.value)
	return out


# ── Cryo Lance ───────────────────────────────────────────────────────────────

func test_cryo_lance_turns_the_highest_held_die_to_a_one_and_hands_its_own_over() -> void:
	_held(2)
	_held(6)
	_held(4)
	var events: Array[EffectEvent] = await _drop(_tile("cryo_lance"), 1)
	assert_eq(events.filter(func(e: EffectEvent) -> bool: return e is ChangeHeldDiceEvent).size(), 1)
	assert_eq(_faces(enemy.dice_manager), [2, 1, 4, 1] as Array[int],
		"the 6 froze to a 1, the rest stand, and the lance's 1 joined them")


func test_cryo_lance_freezes_only_one_of_a_tied_pair() -> void:
	_held(5)
	_held(5)
	await _drop(_tile("cryo_lance"), 1)
	assert_eq(_faces(enemy.dice_manager), [1, 5, 1] as Array[int])

func test_cryo_lance_refuses_when_the_target_holds_nothing_to_freeze() -> void:
	var tile: Tile = _tile("cryo_lance")
	assert_ne(tile.activation_refusal(_die(1)), "", "an empty hand")
	_held(1)
	assert_ne(tile.activation_refusal(_die(1)), "", "only a 1, which is already frozen")
	_held(2)
	assert_eq(tile.activation_refusal(_die(1)), "")

func test_a_dice_freeze_stops_the_cryo_lance_too() -> void:
	var event := ChangeHeldDiceEvent.new()
	event.change = ChangeHeldDiceEvent.Change.SET_HIGHEST
	assert_true(event.changes_die_values(), "Flash Freeze cancels it like any face change")

# ── Counter-Battery ──────────────────────────────────────────────────────────

## A table whose 6 is an attack and every other face does nothing.
func _table(ship: Enemy) -> EnemyActionResource:
	var actions: Array[EnemyActionResource] = []
	for face: int in range(1, 7):
		actions.append(Ships.attack() if face == 6 else DO_NOTHING.duplicate(true))
	Ships.set_table(ship, actions)
	return actions[5]


func test_counter_battery_silences_the_face_it_hands_over() -> void:
	var attack: EnemyActionResource = _table(enemy)
	var events: Array[EffectEvent] = await _drop(_tile("counter_battery"), 6)
	assert_eq(events.filter(func(e: EffectEvent) -> bool: return e is SilenceFaceEvent).size(), 1)
	var slot: EnemyActionResource = enemy.turn_actions[5]
	assert_eq(slot.silenced_action, attack, "the slot remembers what it cancelled")
	assert_eq(EnemyActionResource.outcome_of(slot, enemy), EnemyActionResource.Outcome.IDLE,
		"and does nothing")
	assert_eq(enemy.threat_of_face(6), EnemyActionResource.Threat.DEAD)
	assert_eq(_faces(enemy.dice_manager), [6] as Array[int], "the 6 went over")


## Where the first event [param matches] sits among [param events], or -1.
func _first(events: Array[EffectEvent], matches: Callable) -> int:
	for i: int in events.size():
		if matches.call(events[i]):
			return i
	return -1


func _is_juice(kind: EffectEnums.AudioVisualSubtype) -> Callable:
	return func(e: EffectEvent) -> bool: return e is JuiceEvent and (e as JuiceEvent).kind == kind


## The battery fires, then the silence lands: the laser and the die thrown at
## the ship come first, and the silence and its callout after them. It used to
## call the silence before the shot had even left.
func _assert_shoots_then_silences(events: Array[EffectEvent], label: String) -> void:
	var laser: int = _first(events, _is_juice(EffectEnums.AudioVisualSubtype.LASER))
	var throw: int = _first(events, func(e: EffectEvent) -> bool: return e is AttackTweenEvent)
	var give: int = _first(events, func(e: EffectEvent) -> bool: return e is GiveDieToTargetEvent)
	var silence: int = _first(events, func(e: EffectEvent) -> bool: return e is SilenceFaceEvent)
	var callout: int = _first(events, _is_juice(EffectEnums.AudioVisualSubtype.CALLOUT))
	for found: int in [laser, throw, give, silence, callout]:
		assert_ne(found, -1, "%s: every beat plays" % label)
	assert_lt(laser, throw, "%s: the laser, then the die" % label)
	assert_lt(throw, give, "%s: the die lands with the ship" % label)
	assert_lt(give, silence, "%s: the shot resolves before the silence" % label)
	assert_lt(silence, callout, "%s: the callout marks the silence" % label)


func test_counter_battery_shoots_before_it_silences() -> void:
	_table(enemy)
	_assert_shoots_then_silences(await _drop(_tile("counter_battery"), 6), "base")
	assert_eq(enemy.threat_of_face(6), EnemyActionResource.Threat.DEAD, "and the silence still lands")


func test_counter_battery_plus_shoots_before_it_silences_every_enemy() -> void:
	var wingman: Enemy = ENEMY_SCENE.instantiate()
	wingman.enemy_resource = INTERCEPTOR
	wingman.scenario_state = ScenarioShipState.new()
	wingman.scenario_state.attitude = Enemy.Attitude.AGGRESSIVE
	# Brought in as before_each() brings in the first: before the fight's
	# state, which would scale its hull by a run that doesn't exist.
	var state: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(wingman)
	Globals.state_manager = state
	Globals.enemy_manager.enemies.append(wingman)
	_table(enemy)
	_table(wingman)

	var events: Array[EffectEvent] = await _drop(_tile("counter_battery_plus"), 6)
	_assert_shoots_then_silences(events, "plus")
	var give: EffectEvent = events[_first(events,
		func(e: EffectEvent) -> bool: return e is GiveDieToTargetEvent)]
	assert_eq(give.targets, [enemy] as Array[Node], "the die goes to the target alone")
	var silence: EffectEvent = events[_first(events,
		func(e: EffectEvent) -> bool: return e is SilenceFaceEvent)]
	assert_eq(silence.targets.size(), 2, "the silence reaches every enemy")
	assert_has(silence.targets, wingman)
	for ship: Enemy in [enemy, wingman]:
		assert_eq(ship.threat_of_face(6), EnemyActionResource.Threat.DEAD)


func test_a_silenced_face_costs_the_player_nothing() -> void:
	_table(enemy)
	assert_gt(AutoPilotThreat.of_face(enemy, 6, false), 0.0)
	enemy.silence_face(6)
	assert_eq(AutoPilotThreat.of_face(enemy, 6, false), 0.0)
	assert_eq(EnemyActionResource.outcome_of(enemy.turn_actions[5], enemy),
		EnemyActionResource.Outcome.IDLE, "so Jammed passes it by")


func test_silencing_only_touches_that_face_and_only_once() -> void:
	_table(enemy)
	var before: Array[EnemyActionResource] = enemy.turn_actions.duplicate()
	assert_true(enemy.silence_face(3))
	assert_false(enemy.silence_face(3), "already silenced")
	assert_false(enemy.silence_face(7), "no such face")
	for face: int in [1, 2, 4, 5, 6]:
		assert_eq(enemy.turn_actions[face - 1], before[face - 1])


func test_the_next_roll_clears_a_silence() -> void:
	# A copy first: the Interceptor's resource is shared.
	enemy.enemy_resource = enemy.enemy_resource.duplicate()
	Ships.give_pool(enemy, [Ships.option(Ships.attack())] as Array[EnemyActionOptionResource])
	_table(enemy)
	enemy.silence_face(6)
	enemy.generate_turn_actions(EnemyActionSituation.for_ship(enemy, [enemy] as Array[Enemy]))
	for action: EnemyActionResource in enemy.turn_actions:
		assert_null(action.silenced_action)


func test_counter_battery_plus_silences_the_face_on_every_enemy() -> void:
	var second: Enemy = ENEMY_SCENE.instantiate()
	second.enemy_resource = INTERCEPTOR
	second.scenario_state = ScenarioShipState.new()
	# Brought in the way before_each() brings in the first: before there is a
	# game state to scale its hull by.
	var state: GameStateManager = Globals.state_manager
	Globals.state_manager = null
	add_child_autofree(second)
	Globals.state_manager = state
	Globals.enemy_manager.enemies = [enemy, second] as Array[Enemy]
	_table(enemy)
	_table(second)
	await _drop(_tile("counter_battery_plus"), 6)
	assert_not_null(enemy.turn_actions[5].silenced_action)
	assert_not_null(second.turn_actions[5].silenced_action)
	assert_eq(_faces(enemy.dice_manager), [6] as Array[int], "the die still goes to the target")
	assert_eq(_faces(second.dice_manager), [] as Array[int])
