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
	assert_eq(rows.size(), 2, "four statuses take two rows")
	assert_true(rows.values().all(func(count: int) -> bool: return count <= 3))


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
