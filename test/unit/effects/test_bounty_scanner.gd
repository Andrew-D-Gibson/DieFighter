extends "res://test/helpers/die_fighter_test.gd"
## Bounty Scanner: a hit that pays credits for each hostile warship it
## destroys. The chain is played whole against a recording engine; the
## BountyDamageEvent it makes is then resolved against bare ships (out of
## the tree, so a kill runs no death sequence) to see what it pays.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")
const Ships := preload("res://test/helpers/ships.gd")
const TILE_SCENE: PackedScene = preload("res://Source/Content/Tiles/tile.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const TILES: String = "res://Source/Content/Tiles/TileResources/%s.tres"

var engine: RecordingEngine


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	Globals.player = make_player(3)
	Globals.tile_grid = autofree(TileGrid.new())
	var state: GameStateManager = autofree(GameStateManager.new())
	Globals.state_manager = state


func after_each() -> void:
	Globals.enemy_manager = null
	super()


## A ship out of the tree, with a reward of its own unless [param launched].
func _ship(hull: int, faction: ScenarioManager.Faction = ScenarioManager.Faction.PIRATE,
		launched: bool = false) -> Enemy:
	var ship: Enemy = autofree(Ships.ship(faction, hull, 20))
	autofree(ship.health)
	if not launched:
		ship.reward_resource = RewardResource.new()
	return ship


## Plays [param tile_id]'s chain with a die of [param face] at [param target]
## and returns the bounty hit it made.
func _play(tile_id: String, face: int, target: Enemy) -> BountyDamageEvent:
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = target
	Globals.targeting_computer = computer
	var roster: EnemyManager = autofree(EnemyManager.new())
	roster.enemies = [target] as Array[Enemy]
	Globals.enemy_manager = roster
	engine.injected.clear()
	var resource: TileResource = load(TILES % tile_id)
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = resource
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = face
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.activator_die = die
	await resource.effect_chain.play(context, engine)
	var hits: Array[EffectEvent] = engine.injected_of(BountyDamageEvent)
	assert_eq(hits.size(), 1, "one bounty hit")
	return hits[0] as BountyDamageEvent if not hits.is_empty() else null


func test_bounty_scanner_hits_for_the_die_less_one() -> void:
	var hit: BountyDamageEvent = await _play("bounty_scanner", 5, _ship(20))
	assert_eq(hit.amount, 4)
	assert_eq(hit.bounty, 8)
	assert_true(hit is DamageEvent, "so it grows and shrinks like any hit")


func test_the_upgrade_hits_for_the_die_and_pays_more() -> void:
	var hit: BountyDamageEvent = await _play("bounty_scanner_plus", 5, _ship(20))
	assert_eq(hit.amount, 5)
	assert_eq(hit.bounty, 12)


func test_a_kill_pays_the_bounty() -> void:
	var ship: Enemy = _ship(4)
	var hit: BountyDamageEvent = await _play("bounty_scanner", 5, ship)
	await hit.resolve(engine)
	assert_eq(ship.health.health, 0)
	assert_eq(hit.paid, 8)


func test_a_hit_that_leaves_the_ship_standing_pays_nothing() -> void:
	var ship: Enemy = _ship(10)
	var hit: BountyDamageEvent = await _play("bounty_scanner", 5, ship)
	await hit.resolve(engine)
	assert_eq(ship.health.health, 6)
	assert_eq(hit.paid, 0)


func test_only_the_killing_hit_is_credited() -> void:
	var ship: Enemy = _ship(4)
	var hit: BountyDamageEvent = await _play("bounty_scanner", 5, ship)
	ship.health.take_damage(4)  # something else finished it first
	await hit.resolve(engine)
	assert_eq(hit.paid, 0)


func test_civilians_and_launched_fighters_carry_no_bounty() -> void:
	var merchant: Enemy = _ship(2, ScenarioManager.Faction.CIVILIAN)
	var hit: BountyDamageEvent = await _play("bounty_scanner", 6, merchant)
	await hit.resolve(engine)
	assert_eq(merchant.health.health, 0)
	assert_eq(hit.paid, 0, "a merchant, even one picked a fight with")
	var fighter: Enemy = _ship(2, ScenarioManager.Faction.PIRATE, true)
	hit = await _play("bounty_scanner", 6, fighter)
	await hit.resolve(engine)
	assert_eq(hit.paid, 0, "a launched fighter, so a Carrier can't be farmed")
	assert_true(BountyDamageEvent.carries_bounty(_ship(2, ScenarioManager.Faction.BOSS)))


func test_the_payout_floats_off_the_wreck_as_coins() -> void:
	var holder: Node2D = add_child_autofree(Node2D.new())
	var ship: Enemy = _ship(3)
	var hit: BountyDamageEvent = await _play("bounty_scanner", 6, ship)
	hit.coin_parent = holder
	await hit.resolve(engine)
	var coins: int = 0
	for coin: Node in get_tree().get_nodes_in_group("Money"):
		if coin is MoneyParticle and coin.get_parent() == holder:
			coins += (coin as MoneyParticle).amount
			coin.free()
	assert_eq(coins, 8, "the credits land when the coins reach the counter")


func test_the_autopilot_counts_the_hit_as_damage() -> void:
	var ship: Enemy = _ship(20)
	var computer: TargetingComputer = autofree(TargetingComputer.new())
	computer.targeted_enemy = ship
	Globals.targeting_computer = computer
	var tile: Tile = autofree(TILE_SCENE.instantiate())
	tile.sprite_frames = null
	tile.tile_resource = load(TILES % "bounty_scanner")
	var die: Dice = autofree(DICE_SCENE.instantiate())
	die.value = 6
	var forecast: AutoPilotForecast = AutoPilotForecast.of(tile, die, ship, [ship] as Array[Enemy])
	assert_eq(forecast.damage.get(ship, 0.0), 5.0)
