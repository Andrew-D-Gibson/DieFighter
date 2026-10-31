extends "res://test/helpers/die_fighter_test.gd"
## Statuses on the player's ship: the same statuses as the enemies', with the
## player's side of each rule (tiles where an enemy has its table), their own
## tick, and an end when the fight ends.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const DAMAGE_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/damage.tres")
const SHIELD_TILE: TileResource = preload("res://Source/Content/Tiles/TileResources/shield.tres")

var player: Player
var engine: RecordingEngine


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	engine = autofree(RecordingEngine.new())


func _enemy() -> Enemy:
	var enemy: Enemy = autofree(ENEMY_SCENE.instantiate())
	enemy.health.max_health = 20
	enemy.health.health = 20
	enemy.scenario_state = ScenarioShipState.new()
	return enemy


func _apply(target: Node2D, status_id: StringName, stacks: int) -> StatusModifier:
	var event: ApplyStatusEvent = ApplyStatusEvent.new()
	event.status_id = status_id
	event.amount = stacks
	event.targets = [target]
	await event.resolve(engine)
	return engine.find_status(target, status_id)


## A tile outside the tree; its sprite is dropped so the resource setter
## doesn't start a tween that needs the tree.
func _tile(resource: TileResource, on_grid: bool = true) -> Tile:
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	if on_grid:
		var grid: TileGrid = autofree(TileGrid.new())
		grid.tile_locations[Vector2i(0, 0)] = tile
		Globals.tile_grid = grid
	return tile


func _die(value: int) -> Dice:
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = value
	return die


func _activation(tile: Tile, die: Dice, feed_depth: int = 0) -> TileActivationEvent:
	var event: TileActivationEvent = TileActivationEvent.new()
	event.tile = tile
	event.activator_die = die
	event.die_value = die.value if die else 0
	event.feed_depth = feed_depth
	return event


# ── Applying and showing ──────────────────────────────────────────────────────

func test_a_status_on_the_player_gets_a_badge_on_the_players_bar() -> void:
	await _apply(player, &"burn", 2)
	await _apply(player, &"jammed", 1)
	assert_eq(engine.statuses_on(player).size(), 2)
	assert_eq(player.get_status_bar().get_child_count(), 2)


func test_statuses_that_work_differently_on_the_player_explain_that_side() -> void:
	for status_id: StringName in StatusCatalog.ids():
		var status: StatusModifier = StatusCatalog.create(status_id, player, 1)
		assert_false(Keywords.definition(status.rule_term()).is_empty(),
			"%s has no rule for the player" % status_id)
	assert_eq(StatusCatalog.create(&"jammed", player, 1).rule_term(), "Jammed (you)")
	assert_eq(StatusCatalog.create(&"scrambled", player, 1).rule_term(), "Scrambled (you)")
	assert_eq(StatusCatalog.create(&"burn", player, 1).rule_term(), "Burn", "Burn reads the same either side")
	assert_eq(StatusCatalog.create(&"jammed", _enemy(), 1).rule_term(), "Jammed")


func test_the_player_bar_wraps_clear_of_the_systems_panel() -> void:
	for status_id: StringName in StatusCatalog.ids():
		await _apply(player, status_id, 1)
	var rows: Dictionary[float, int] = {}
	for badge: Node in player.get_status_bar().get_children():
		var y: float = (badge as Node2D).position.y
		rows[y] = rows.get(y, 0) + 1
	var per_row: int = player.get_status_bar().per_row
	assert_gt(per_row, 0, "the player's bar wraps")
	var expected_rows: int = ceili(StatusCatalog.ids().size() / float(per_row))
	assert_eq(rows.size(), expected_rows, "every status, %d to a row" % per_row)
	assert_true(rows.values().all(func(count: int) -> bool: return count <= per_row))


func test_a_status_a_tile_puts_on_its_own_ship_is_not_amplified() -> void:
	var self_burn: ApplyStatusEvent = ApplyStatusEvent.new()
	self_burn.actor = player
	self_burn.targets = [player]
	assert_false(self_burn.is_amplifiable(), "a cost, which a boost never grows")

	var on_enemy: ApplyStatusEvent = ApplyStatusEvent.new()
	on_enemy.actor = player
	on_enemy.targets = [_enemy()]
	assert_true(on_enemy.is_amplifiable())


# ── Ticking and ending ────────────────────────────────────────────────────────

func test_each_side_ticks_on_its_own_call() -> void:
	var enemy := _enemy()
	var their_burn: StatusModifier = await _apply(enemy, &"burn", 3)
	var my_burn: StatusModifier = await _apply(player, &"burn", 2)

	engine.tick_statuses()
	assert_eq(their_burn.stacks, 2, "the enemy turn starts: their burn ticks")
	assert_eq(my_burn.stacks, 2, "not the player's")

	engine.tick_statuses(true)
	assert_eq(my_burn.stacks, 1, "the enemy turn ends: the player's ticks")
	assert_eq(their_burn.stacks, 2)

	var hits: Array[EffectEvent] = engine.injected_of(DamageEvent)
	assert_eq(hits.size(), 2)
	assert_eq(hits[1].targets, [player] as Array[Node])
	assert_eq(hits[1].amount, 2)
	assert_null(hits[1].effect_source, "the fire is no one's hit, so Exposed ignores it")


func test_the_players_statuses_end_with_the_fight() -> void:
	var enemy := _enemy()
	await _apply(player, &"burn", 2)
	await _apply(player, &"exposed", 1)
	await _apply(enemy, &"burn", 2)
	Events.combat_finished.emit()
	assert_eq(engine.statuses_on(player).size(), 0)
	assert_not_null(engine.find_status(enemy, &"burn"), "an enemy's status leaves with its ship")


# ── Exposed ───────────────────────────────────────────────────────────────────

func test_exposed_on_the_player_grows_enemy_hits_only() -> void:
	var exposed: StatusModifier = await _apply(player, &"exposed", 2)
	var enemy := _enemy()

	var own_fire: DamageEvent = DamageEvent.new()
	own_fire.targets = [player]
	own_fire.amount = 3
	exposed.on_before_event(own_fire, engine)
	assert_eq(own_fire.amount, 3, "burn and the redline aren't hits")

	var shot: DamageEvent = DamageEvent.new()
	shot.effect_source = enemy
	shot.targets = [player]
	shot.amount = 3
	exposed.on_before_event(shot, engine)
	assert_eq(shot.amount, 5)
	assert_eq(exposed.stacks, 1)


# ── Weakened ──────────────────────────────────────────────────────────────────

func _tile_hit(targets: Array[Node], amount: int) -> DamageEvent:
	var hit: DamageEvent = DamageEvent.new()
	hit.effect_source = _tile(DAMAGE_TILE, false)
	hit.targets = targets
	hit.amount = amount
	return hit


func test_weakened_on_the_player_shrinks_tile_hits_on_other_ships() -> void:
	var weakened: StatusModifier = await _apply(player, &"weakened", 1)
	var enemy := _enemy()
	assert_eq(weakened.rule_term(), "Weakened (you)")

	var shot := _tile_hit([enemy], 8)
	var blast := _tile_hit([enemy, player], 4)
	var own_cost := _tile_hit([player], 4)
	var enemy_fire: DamageEvent = DamageEvent.new()
	enemy_fire.effect_source = enemy
	enemy_fire.targets = [player]
	enemy_fire.amount = 4
	for hit: DamageEvent in [shot, blast, own_cost, enemy_fire]:
		weakened.on_before_event(hit, engine)
	assert_eq(shot.amount, 6)
	assert_eq(blast.amount, 3, "an all-ships blast is still the player's attack")
	assert_eq(own_cost.amount, 4, "a tile's cost to the hull isn't an attack")
	assert_eq(enemy_fire.amount, 4, "the enemy's hits are its own business")


func test_the_players_weakened_wears_off_as_they_end_their_turn() -> void:
	var weakened: StatusModifier = await _apply(player, &"weakened", 2)
	engine.tick_statuses(true)
	Events.enemy_turn_over.emit()
	assert_eq(weakened.stacks, 2, "put on during the enemy turn, it lasts the player's next one")
	Events.player_turn_over.emit()
	assert_eq(weakened.stacks, 1)
	Events.player_turn_over.emit()
	assert_null(engine.find_status(player, &"weakened"))


func test_weakened_cuts_the_hit_after_exposed_grows_it() -> void:
	var enemy := _enemy()
	await _apply(player, &"weakened", 1)
	await _apply(enemy, &"exposed", 2)
	var hit := _tile_hit([enemy], 4)
	engine.sort_modifiers()
	for mod: Modifier in engine.modifiers.duplicate():
		mod.on_before_event(hit, engine)
	assert_eq(hit.amount, 4, "(4 + 2 Exposed) less a quarter")


func test_countermeasures_hand_weakened_to_the_enemy_and_its_turn_clock() -> void:
	var enemy := _enemy()
	await _apply(player, &"weakened", 2)
	await _transfer(player, enemy)
	assert_null(engine.find_status(player, &"weakened"))
	var moved: StatusModifier = engine.find_status(enemy, &"weakened")
	assert_eq(moved.stacks, 2)
	assert_eq(moved.rule_term(), "Weakened")

	var shot: DamageEvent = DamageEvent.new()
	shot.effect_source = enemy
	shot.targets = [player]
	shot.amount = 4
	moved.on_before_event(shot, engine)
	assert_eq(shot.amount, 3, "now it's the enemy's hits that shrink")

	Events.player_turn_over.emit()
	assert_eq(moved.stacks, 2, "the player's turn ending no longer counts it down")
	Events.enemy_turn_over.emit()
	assert_eq(moved.stacks, 1)


# ── Jammed ────────────────────────────────────────────────────────────────────

func test_jammed_cancels_the_next_activation_and_sends_the_die_on() -> void:
	var jammed: StatusModifier = await _apply(player, &"jammed", 1)
	# Shield Burst takes a 3 and needs no target, so it would fire.
	var tile: Tile = _tile(SHIELD_TILE)
	var die: Dice = _die(3)
	var activation: TileActivationEvent = _activation(tile, die)

	jammed.on_before_event(activation, engine)
	assert_true(activation.canceled)
	var jams: Array[EffectEvent] = engine.injected_of(JammedTileEvent)
	assert_eq(jams.size(), 1)
	assert_eq((jams[0] as JammedTileEvent).tile, tile)
	assert_eq(jams[0].activator_die, die)
	assert_null(engine.find_status(player, &"jammed"), "spent")


func test_jammed_keeps_its_stack_for_a_die_the_tile_would_refuse() -> void:
	var jammed: StatusModifier = await _apply(player, &"jammed", 1)
	var refused: TileActivationEvent = _activation(_tile(SHIELD_TILE), _die(5))
	jammed.on_before_event(refused, engine)
	assert_false(refused.canceled, "the tile bounces it back to the hand itself")
	assert_eq(jammed.stacks, 1)


func test_jammed_leaves_the_cockpit_controls_and_dieless_activations_alone() -> void:
	var jammed: StatusModifier = await _apply(player, &"jammed", 1)
	var off_grid: TileActivationEvent = _activation(_tile(SHIELD_TILE, false), _die(3))
	jammed.on_before_event(off_grid, engine)
	assert_false(off_grid.canceled, "a map tile or the Engine Charger isn't a system")

	var self_activation: TileActivationEvent = _activation(_tile(SHIELD_TILE), null)
	jammed.on_before_event(self_activation, engine)
	assert_false(self_activation.canceled)
	assert_eq(jammed.stacks, 1)


func test_a_jammed_enemy_still_only_jams_its_own_actions() -> void:
	var jammed: StatusModifier = await _apply(_enemy(), &"jammed", 1)
	var activation: TileActivationEvent = _activation(_tile(SHIELD_TILE), _die(3))
	jammed.on_before_event(activation, engine)
	assert_false(activation.canceled)


# ── Scrambled ─────────────────────────────────────────────────────────────────

func test_scrambled_flips_dice_placed_from_the_hand() -> void:
	var scrambled: StatusModifier = await _apply(player, &"scrambled", 1)
	var tile: Tile = _tile(DAMAGE_TILE)
	var die: Dice = _die(5)
	var activation: TileActivationEvent = _activation(tile, die)

	scrambled.on_before_event(activation, engine)
	assert_eq(die.value, 2)
	assert_eq(activation.die_value, 2, "what later hooks read")
	assert_null(engine.find_status(player, &"scrambled"))


func test_scrambled_leaves_fed_dice_alone() -> void:
	var scrambled: StatusModifier = await _apply(player, &"scrambled", 1)
	var die: Dice = _die(5)
	scrambled.on_before_event(_activation(_tile(DAMAGE_TILE), die, 1), engine)
	assert_eq(die.value, 5)
	assert_eq(scrambled.stacks, 1)


func test_scrambled_runs_before_jammed_so_the_jam_sees_the_flipped_face() -> void:
	var scrambled: StatusModifier = StatusCatalog.create(&"scrambled", player, 1)
	var jammed: StatusModifier = StatusCatalog.create(&"jammed", player, 1)
	assert_lt(scrambled.priority, jammed.priority)
	assert_gt(scrambled.priority, LockoutModifier.new(null).priority, "a lock reads the face it was given")


# ── Moving statuses ───────────────────────────────────────────────────────────

func _transfer(from: Node, to: Node) -> void:
	var event: TransferStatusesEvent = TransferStatusesEvent.new()
	event.actor = from
	event.targets = [to]
	await event.resolve(engine)


func test_transfer_moves_every_status_and_merges_into_the_targets() -> void:
	var enemy := _enemy()
	await _apply(player, &"burn", 3)
	await _apply(player, &"jammed", 1)
	await _apply(enemy, &"burn", 2)

	await _transfer(player, enemy)
	assert_eq(engine.statuses_on(player).size(), 0)
	assert_eq(engine.find_status(enemy, &"burn").stacks, 5)
	var jam: StatusModifier = engine.find_status(enemy, &"jammed")
	assert_eq(jam.affected_node, enemy, "rebuilt for its new host")
	assert_eq(jam.rule_term(), "Jammed", "now the enemy's rule")
	assert_eq(enemy.get_status_bar().get_child_count(), 2)


func test_an_enemy_can_vent_its_statuses_onto_the_player() -> void:
	var enemy := _enemy()
	await _apply(enemy, &"scrambled", 2)
	await _transfer(enemy, player)
	assert_null(engine.find_status(enemy, &"scrambled"))
	assert_eq(engine.find_status(player, &"scrambled").stacks, 2)
	assert_eq(player.get_status_bar().get_child_count(), 1)


func test_transfer_leaves_phased_where_it_is() -> void:
	var enemy := _enemy()
	await _apply(player, &"phased", 1)
	await _apply(player, &"burn", 2)
	await _transfer(player, enemy)
	assert_not_null(engine.find_status(player, &"phased"), "a cloak isn't handed over")
	assert_null(engine.find_status(enemy, &"phased"))
	assert_eq(engine.find_status(enemy, &"burn").stacks, 2)


func test_countermeasures_check_wants_a_harmful_status_on_the_player() -> void:
	var real_engine: ScenarioEngine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = real_engine
	Globals.scenario_manager = manager
	Globals.player = player
	var check: ActivationResource = ActivationResource.new()
	check.type = ActivationResource.ActivationType.PLAYER_HAS_HARMFUL_STATUS
	assert_false(check.criteria_satisfied(null), "nothing on you")

	var cloak: ApplyStatusEvent = ApplyStatusEvent.new()
	cloak.status_id = &"phased"
	cloak.amount = 1
	cloak.targets = [player]
	await cloak.resolve(real_engine)
	assert_false(check.criteria_satisfied(null), "Phased doesn't count")

	var burn: ApplyStatusEvent = ApplyStatusEvent.new()
	burn.status_id = &"burn"
	burn.amount = 1
	burn.targets = [player]
	await burn.resolve(real_engine)
	assert_true(check.criteria_satisfied(null))


func test_purge_vents_is_blocked_with_nothing_to_vent() -> void:
	var real_engine: ScenarioEngine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = real_engine
	Globals.scenario_manager = manager
	var enemy := _enemy()
	var vent: EnemyActionResource = load("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/purge_vents.tres").duplicate(true)

	assert_eq(EnemyActionResource.outcome_of(vent, enemy), EnemyActionResource.Outcome.BLOCKED)
	var burn: ApplyStatusEvent = ApplyStatusEvent.new()
	burn.status_id = &"burn"
	burn.amount = 1
	burn.targets = [enemy]
	await burn.resolve(real_engine)
	assert_eq(EnemyActionResource.outcome_of(vent, enemy), EnemyActionResource.Outcome.ACTS)
	assert_eq(EnemyActionResource.outcome_of(vent), EnemyActionResource.Outcome.ACTS, "no ship to ask: assume it can")


# ── Enemy actions ─────────────────────────────────────────────────────────────

func test_statuses_aimed_at_the_player_read_as_dangerous() -> void:
	for file: String in ["incendiary_shot", "target_lock", "jamming_pulse", "scrambler", "purge_vents"]:
		var action: EnemyActionResource = load("res://Source/Content/Enemies/EnemyActions/EnemyActionResources/%s.tres" % file)
		assert_eq(action.get_threat(), EnemyActionResource.Threat.DANGEROUS, file)


func test_self_has_status_gates_on_the_rolling_ships_statuses() -> void:
	var condition: EnemyActionCondition = EnemyActionCondition.new()
	condition.type = EnemyActionCondition.Type.SELF_HAS_STATUS
	var situation: EnemyActionSituation = EnemyActionSituation.new()
	assert_false(condition.is_met(situation))
	situation.statuses = [&"burn"] as Array[StringName]
	assert_true(condition.is_met(situation), "any status")
	condition.status_id = &"jammed"
	assert_false(condition.is_met(situation))
	condition.status_id = &"burn"
	assert_true(condition.is_met(situation))
