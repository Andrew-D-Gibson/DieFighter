extends "res://test/helpers/die_fighter_test.gd"
## Enemy statuses: how they are applied and merged, how stacks are spent, and
## what each one does to the events it hooks.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const ATTACK: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")
const DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")

var engine: ScenarioEngine


func before_each() -> void:
	super()
	engine = autofree(ScenarioEngine.new())


## An enemy outside the tree: real enough to carry statuses and a StatusBar,
## without _ready() reaching for game systems.
func _enemy(hp: int = 20) -> Enemy:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = hp
	enemy.health.health = hp
	return enemy


func _apply(target: Enemy, status_id: StringName, stacks: int) -> void:
	var event: ApplyStatusEvent = ApplyStatusEvent.new()
	event.status_id = status_id
	event.amount = stacks
	event.targets = [target]
	await event.resolve(engine)


func _hit(source: Node, targets: Array[Node], amount: int) -> DamageEvent:
	var hit: DamageEvent = DamageEvent.new()
	hit.effect_source = source
	hit.targets = targets
	hit.amount = amount
	return hit


# ── Applying ──────────────────────────────────────────────────────────────────

func test_catalog_creates_each_status_on_its_host() -> void:
	var enemy := _enemy()
	for status_id: StringName in StatusCatalog.ids():
		var status: StatusModifier = StatusCatalog.create(status_id, enemy, 2)
		assert_eq(status.status_id, status_id)
		assert_eq(status.affected_node, enemy)
		assert_eq(status.stacks, 2)
		assert_false(Keywords.definition(status.display_name).is_empty(),
			"%s has no keyword definition" % status_id)


func test_catalog_rejects_an_unknown_id() -> void:
	assert_null(StatusCatalog.create(&"nope", _enemy(), 1))
	assert_push_error("no status with id 'nope'")


func test_applying_twice_merges_stacks_into_one_status() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"burn", 2)
	await _apply(enemy, &"burn", 3)
	assert_eq(engine.statuses_on(enemy).size(), 1)
	assert_eq(engine.find_status(enemy, &"burn").stacks, 5)


func test_different_statuses_sit_side_by_side_with_badges() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"burn", 1)
	await _apply(enemy, &"exposed", 1)
	assert_eq(engine.statuses_on(enemy).size(), 2)
	assert_eq(enemy.get_status_bar().get_child_count(), 2)


func test_statuses_are_not_applied_to_a_dead_ship() -> void:
	var enemy := _enemy()
	enemy.health.health = 0
	await _apply(enemy, &"burn", 3)
	assert_null(engine.find_status(enemy, &"burn"))


func test_applied_stacks_are_amplifiable() -> void:
	assert_true(ApplyStatusEvent.new().is_amplifiable())


# ── Spending and cleanup ──────────────────────────────────────────────────────

func test_spending_the_last_stack_removes_the_status_and_its_badge() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"jammed", 2)
	var status: StatusModifier = engine.find_status(enemy, &"jammed")
	status.consume(1)
	assert_eq(status.stacks, 1)
	status.consume(1)
	assert_null(engine.find_status(enemy, &"jammed"))
	await wait_process_frames(1)
	assert_eq(enemy.get_status_bar().get_child_count(), 0)


func test_a_ship_leaving_takes_its_statuses_with_it() -> void:
	var enemy := _enemy()
	var other := _enemy()
	await _apply(enemy, &"burn", 3)
	await _apply(other, &"burn", 3)
	Events.enemy_left.emit(enemy, ScenarioManager.Faction.PIRATE)
	assert_null(engine.find_status(enemy, &"burn"))
	assert_not_null(engine.find_status(other, &"burn"), "only the ship that left")


func test_clear_status_removes_every_stack() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"burn", 4)
	var clear: ClearStatusEvent = ClearStatusEvent.new()
	clear.status_id = &"burn"
	clear.targets = [enemy]
	await clear.resolve(engine)
	assert_null(engine.find_status(enemy, &"burn"))


# ── Burn ──────────────────────────────────────────────────────────────────────

func test_burn_ticks_for_its_stacks_then_loses_one() -> void:
	var recorder: RecordingEngine = autofree(RecordingEngine.new())
	var enemy := _enemy()
	var burn: StatusModifier = StatusCatalog.create(&"burn", enemy, 3)
	recorder.add_modifier(burn)

	recorder.tick_statuses()
	var hits: Array[EffectEvent] = recorder.injected_of(DamageEvent)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 3)
	assert_eq(hits[0].targets, [enemy] as Array[Node])
	assert_null(hits[0].effect_source, "burn is not a tile's hit")
	assert_eq(burn.stacks, 2)

	recorder.tick_statuses()
	recorder.tick_statuses()
	assert_eq(recorder.injected_of(DamageEvent).map(func(e: EffectEvent) -> int: return e.amount), [3, 2, 1])
	assert_null(recorder.find_status(enemy, &"burn"), "burnt out")


# ── Scrambled ─────────────────────────────────────────────────────────────────

func test_scrambled_flips_each_arriving_die_until_it_runs_out() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"scrambled", 2)
	var scrambled: ScrambledStatus = engine.find_status(enemy, &"scrambled")

	var dice: Array = [FakeDie.new(6), FakeDie.new(2), FakeDie.new(3)]
	for die: Node in dice:
		autofree(die)
		scrambled.on_die_arriving(die)

	assert_eq(dice.map(func(d: Node) -> int: return d.value), [1, 5, 3],
		"two stacks flip two dice; the third arrives as rolled")
	assert_null(engine.find_status(enemy, &"scrambled"))


func test_a_scrambled_die_is_flipped_before_anyone_sees_it_arrive() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"scrambled", 2)
	var intake: EnemyDiceManager = enemy.dice_manager
	# The targeting computer redraws the intent highlight on die_added.
	var seen: Array[int] = []
	intake.die_added.connect(func() -> void: seen.append(intake.queue[-1].value))

	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 6
	intake.add(die)
	assert_eq(seen, [1] as Array[int])

	# A ship putting back a die it already held (Charge Bore) receives nothing.
	intake.remove(die)
	intake.add(die)
	assert_eq(die.value, 1)
	assert_eq(engine.find_status(enemy, &"scrambled").stacks, 1)


func test_scrambled_listens_to_its_own_ships_intake() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"scrambled", 1)
	assert_true(enemy.dice_manager.die_arriving.is_connected(
		engine.find_status(enemy, &"scrambled").on_die_arriving))


# ── Jammed ────────────────────────────────────────────────────────────────────

func test_jammed_turns_its_ships_actions_into_nothing() -> void:
	var enemy := _enemy()
	var other := _enemy()
	await _apply(enemy, &"jammed", 1)
	var jammed: StatusModifier = engine.find_status(enemy, &"jammed")

	var theirs: EnemyActionEvent = EnemyActionEvent.new()
	theirs.enemy = other
	theirs.action = ATTACK
	jammed.on_before_event(theirs, engine)
	assert_eq(theirs.action, ATTACK, "another ship's action is untouched")

	var own: EnemyActionEvent = EnemyActionEvent.new()
	own.enemy = enemy
	own.action = ATTACK
	jammed.on_before_event(own, engine)
	assert_eq(own.action, DO_NOTHING)
	assert_null(engine.find_status(enemy, &"jammed"))


# ── Exposed ───────────────────────────────────────────────────────────────────

func test_exposed_adds_its_stacks_to_the_next_tile_hit_and_is_spent() -> void:
	var enemy := _enemy()
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	await _apply(enemy, &"exposed", 4)
	var exposed: StatusModifier = engine.find_status(enemy, &"exposed")

	var hit := _hit(tile, [enemy], 3)
	exposed.on_before_event(hit, engine)
	assert_eq(hit.amount, 7)
	assert_null(engine.find_status(enemy, &"exposed"))


func test_exposed_ignores_sourceless_area_and_other_ships_hits() -> void:
	var enemy := _enemy()
	var other := _enemy()
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	await _apply(enemy, &"exposed", 4)
	var exposed: StatusModifier = engine.find_status(enemy, &"exposed")

	var burn_tick := _hit(null, [enemy], 3)
	var area := _hit(tile, [enemy, other], 3)
	var elsewhere := _hit(tile, [other], 3)
	for hit: DamageEvent in [burn_tick, area, elsewhere]:
		exposed.on_before_event(hit, engine)
		assert_eq(hit.amount, 3)
	assert_eq(exposed.stacks, 4)


# ── Reading statuses from effects ─────────────────────────────────────────────

func test_effects_can_read_a_targets_status() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"burn", 4)
	var context := EffectContext.new()
	context.targets = [enemy]

	var read := Effects.data(EffectEnums.Category.AMOUNT_MODIFIER,
		EffectEnums.AmountModifierSubtype.SET_TO_TARGET_STATUS)
	read.string_param = "burn"
	SetAmountToTargetStatusHandler.new().apply(read, context, engine)
	assert_eq(context.running_amount, 4)

	read.string_param = "jammed"
	SetAmountToTargetStatusHandler.new().apply(read, context, engine)
	assert_eq(context.running_amount, 0)


func test_if_target_has_status_branches_on_it() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"scrambled", 1)
	var context := EffectContext.new()
	context.targets = [enemy]

	var cond := ConditionalEffectData.new()
	cond.category = EffectEnums.Category.CONDITIONAL
	cond.subtype = EffectEnums.ConditionalSubtype.IF_TARGET_HAS_STATUS
	cond.string_param = "scrambled"
	cond.if_true_effects = [Effects.set_amount(1)]
	cond.if_false_effects = [Effects.set_amount(2)]

	await ConditionalHandler.new().apply(cond, context, engine)
	assert_eq(context.running_amount, 1)

	cond.string_param = "burn"
	await ConditionalHandler.new().apply(cond, context, engine)
	assert_eq(context.running_amount, 2)
