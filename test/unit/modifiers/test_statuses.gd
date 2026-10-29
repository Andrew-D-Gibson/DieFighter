extends "res://test/helpers/die_fighter_test.gd"
## Enemy statuses: how they are applied and merged, how stacks are spent, and
## what each one does to the events it hooks.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const ATTACK: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/attack_player.tres")
const DO_NOTHING: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/do_nothing.tres")
const REPAIR: EnemyActionResource = preload("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/repair_ally.tres")

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


func test_a_status_from_the_player_counts_as_an_attack() -> void:
	var enemy := _enemy()
	enemy.scenario_state = ScenarioShipState.new()
	enemy.scenario_state.faction = ScenarioManager.Faction.CIVILIAN
	watch_signals(Events)
	var event: ApplyStatusEvent = ApplyStatusEvent.new()
	event.actor = autofree(Player.new())
	event.status_id = &"jammed"
	event.amount = 1
	event.targets = [enemy]
	await event.resolve(engine)
	assert_signal_emitted_with_parameters(Events, "player_attacked_ship",
		[enemy, ScenarioManager.Faction.CIVILIAN])


func test_a_status_from_no_one_provokes_nobody() -> void:
	watch_signals(Events)
	await _apply(_enemy(), &"burn", 1)
	assert_signal_not_emitted(Events, "player_attacked_ship")


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
	assert_eq(own.action.name, DO_NOTHING.name)
	assert_ne(own.action, DO_NOTHING, "a copy, so the shared resource is never bound")
	assert_null(engine.find_status(enemy, &"jammed"))


func test_jammed_keeps_its_stacks_through_dice_that_would_do_nothing() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"jammed", 1)
	var jammed: StatusModifier = engine.find_status(enemy, &"jammed")

	var idle: EnemyActionEvent = EnemyActionEvent.new()
	idle.enemy = enemy
	idle.action = DO_NOTHING
	jammed.on_before_event(idle, engine)
	assert_eq(idle.action, DO_NOTHING)

	# A support whose ally has gone: it meant to act, but can't.
	var dead_ally := _enemy()
	dead_ally.health.health = 0
	var repair: EnemyActionResource = REPAIR.duplicate(true)
	repair.bound_target = dead_ally
	var blocked: EnemyActionEvent = EnemyActionEvent.new()
	blocked.enemy = enemy
	blocked.action = repair
	jammed.on_before_event(blocked, engine)
	assert_eq(blocked.action, repair, "left for EnemyActionEvent to show as blocked")

	var empty: EnemyActionEvent = EnemyActionEvent.new()
	empty.enemy = enemy
	jammed.on_before_event(empty, engine)
	assert_eq(jammed.stacks, 1, "nothing worth jamming yet")

	var attack: EnemyActionEvent = EnemyActionEvent.new()
	attack.enemy = enemy
	attack.action = ATTACK
	jammed.on_before_event(attack, engine)
	assert_eq(attack.action.name, DO_NOTHING.name, "spent on the first die that would act")
	assert_null(engine.find_status(enemy, &"jammed"))


# ── Exposed ───────────────────────────────────────────────────────────────────

func test_exposed_adds_its_stacks_to_each_tile_hit_and_spends_one() -> void:
	var enemy := _enemy()
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	await _apply(enemy, &"exposed", 2)
	var exposed: StatusModifier = engine.find_status(enemy, &"exposed")

	var first := _hit(tile, [enemy], 3)
	exposed.on_before_event(first, engine)
	assert_eq(first.amount, 5)
	assert_eq(exposed.stacks, 1)

	var second := _hit(tile, [enemy], 3)
	exposed.on_before_event(second, engine)
	assert_eq(second.amount, 4)
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


# ── Weakened ──────────────────────────────────────────────────────────────────

func test_weakened_takes_a_quarter_off_rounded_down_but_never_below_one() -> void:
	# A quarter off, the cut rounding up: even a 2 loses one.
	var expected: Dictionary[int, int] = {0: 0, 1: 1, 2: 1, 3: 2, 4: 3, 5: 3, 6: 4, 8: 6, 10: 7, 12: 9}
	for hit: int in expected:
		assert_eq(WeakenedStatus.weakened(hit), expected[hit], "a weakened %d" % hit)


func test_weakened_shrinks_its_own_ships_hits_and_keeps_its_stacks() -> void:
	var enemy := _enemy()
	var other := _enemy()
	await _apply(enemy, &"weakened", 2)
	var weakened: StatusModifier = engine.find_status(enemy, &"weakened")

	var on_player := _hit(enemy, [make_player()], 6)
	var on_ally := _hit(enemy, [other], 4)
	for hit: DamageEvent in [on_player, on_ally]:
		weakened.on_before_event(hit, engine)
	assert_eq(on_player.amount, 4)
	assert_eq(on_ally.amount, 3, "any ship it hits")
	assert_eq(weakened.stacks, 2, "hits don't spend it; turns do")


func test_weakened_leaves_hits_it_didnt_throw_alone() -> void:
	var enemy := _enemy()
	var other := _enemy()
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	await _apply(enemy, &"weakened", 1)
	var weakened: StatusModifier = engine.find_status(enemy, &"weakened")

	var taken := _hit(tile, [enemy], 6)
	var burn_tick := _hit(null, [enemy], 6)
	var someone_else := _hit(other, [enemy], 6)
	for hit: DamageEvent in [taken, burn_tick, someone_else]:
		weakened.on_before_event(hit, engine)
		assert_eq(hit.amount, 6)


func test_an_enemys_weakened_wears_off_as_its_turn_ends() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"weakened", 2)
	var weakened: StatusModifier = engine.find_status(enemy, &"weakened")

	engine.tick_statuses()
	Events.player_turn_over.emit()
	assert_eq(weakened.stacks, 2, "it waits for the ship to have fired its turn")
	Events.enemy_turn_over.emit()
	assert_eq(weakened.stacks, 1)
	Events.enemy_turn_over.emit()
	assert_null(engine.find_status(enemy, &"weakened"))
	assert_false(Events.enemy_turn_over.is_connected(weakened._on_own_turn_end),
		"a spent status stops listening")


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
