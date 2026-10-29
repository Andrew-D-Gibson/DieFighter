extends "res://test/helpers/die_fighter_test.gd"
## The tiles that put Weakened on enemies play their chains whole: what they
## apply and to whom, where the die goes, which faces they take, and that the
## status they leave really does shrink the ship's next hit.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine
var enemy: Enemy
var other: Enemy


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	enemy = _enemy()
	other = _enemy()
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = enemy
	Globals.targeting_computer = computer
	# "Every enemy" and "random enemy" read the roster.
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [enemy, other] as Array[Enemy]
	Globals.enemy_manager = roster


func after_each() -> void:
	Globals.enemy_manager = null
	super()


func _enemy() -> Enemy:
	var ship: Enemy = autofree(ENEMY_SCENE.instantiate())
	ship.health.max_health = 40
	ship.health.health = 40
	ship.scenario_state = ScenarioShipState.new()
	return ship


func _tile(tile_id: String) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = load(TILES % tile_id)
	return tile


func _die(face: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	return die


## Plays [param tile_id]'s chain with a die showing [param face] and returns
## what it produced.
func _play(tile_id: String, face: int) -> Array[EffectEvent]:
	engine.injected.clear()
	Globals.player = make_player(3)
	var grid: TileGrid = autofree(TileGrid.new())
	Globals.tile_grid = grid
	var tile: Tile = _tile(tile_id)
	grid.tile_locations[Vector2i(1, 1)] = tile
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = _die(face)
	await tile.tile_resource.effect_chain.play(context, engine)
	return engine.injected.duplicate()


func _of(events: Array[EffectEvent], script: Script) -> Array[EffectEvent]:
	return events.filter(func(e: EffectEvent) -> bool: return is_instance_of(e, script))


func _weakens(events: Array[EffectEvent]) -> Array[ApplyStatusEvent]:
	var out: Array[ApplyStatusEvent] = []
	for event: EffectEvent in _of(events, ApplyStatusEvent):
		if (event as ApplyStatusEvent).status_id == &"weakened":
			out.append(event as ApplyStatusEvent)
	return out


func _takes(tile_id: String, face: int) -> bool:
	return _tile(tile_id).activation_refusal(_die(face)).is_empty()


## The ship's own 8-damage shot, run past whatever statuses it now carries.
func _next_shot_from(ship: Enemy) -> int:
	var shot: DamageEvent = DamageEvent.new()
	shot.effect_source = ship
	shot.targets = [Globals.player]
	shot.amount = 8
	for status: StatusModifier in engine.statuses_on(ship):
		status.on_before_event(shot, engine)
	return shot.amount


# ── Dampener ──────────────────────────────────────────────────────────────────

func test_dampener_weakens_the_target_and_hands_it_the_die() -> void:
	var events: Array[EffectEvent] = await _play("dampener", 5)
	var weakens: Array[ApplyStatusEvent] = _weakens(events)
	assert_eq(weakens.size(), 1)
	assert_eq(weakens[0].amount, 2)
	assert_eq(weakens[0].targets, [enemy] as Array[Node])
	var gives: Array[EffectEvent] = _of(events, GiveDieToTargetEvent)
	assert_eq(gives.size(), 1)
	assert_eq(gives[0].targets, [enemy] as Array[Node], "the core trade: the die goes to the target")
	assert_eq(_of(events, DamageEvent).size(), 0)

	await weakens[0].resolve(engine)
	assert_eq(_next_shot_from(enemy), 6, "its next shot loses a quarter")
	assert_eq(_next_shot_from(other), 8)


func test_dampener_takes_any_die_but_needs_a_target() -> void:
	for face: int in range(1, 7):
		assert_true(_takes("dampener", face), "takes a %d" % face)
	Globals.targeting_computer.targeted_enemy = null
	assert_false(_takes("dampener", 3), "with nobody targeted the die stays home")


func test_dampener_plus_applies_three() -> void:
	assert_eq(_weakens(await _play("dampener_plus", 2))[0].amount, 3)


# ── Concussion Round ──────────────────────────────────────────────────────────

func test_concussion_round_hits_then_weakens_the_target() -> void:
	var events: Array[EffectEvent] = await _play("concussion_round", 3)
	var hits: Array[EffectEvent] = _of(events, DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 4, "a flat 4, whichever face")
	assert_eq(hits[0].targets, [enemy] as Array[Node])
	var weakens: Array[ApplyStatusEvent] = _weakens(events)
	assert_eq(weakens.size(), 1)
	assert_eq(weakens[0].amount, 1)
	assert_eq(weakens[0].targets, [enemy] as Array[Node])
	assert_lt(events.find(hits[0]), events.find(weakens[0]), "the hit lands first")
	assert_eq(_of(events, GiveDieToTargetEvent)[0].targets, [enemy] as Array[Node])


func test_concussion_round_takes_only_threes_and_fours() -> void:
	for face: int in range(1, 7):
		assert_eq(_takes("concussion_round", face), face == 3 or face == 4, "a %d" % face)


func test_concussion_round_plus_hits_for_six() -> void:
	var events: Array[EffectEvent] = await _play("concussion_round_plus", 4)
	assert_eq(_of(events, DamageEvent)[0].amount, 6)
	assert_eq(_weakens(events)[0].amount, 1)
