extends "res://test/helpers/die_fighter_test.gd"

const RecordingEngine: GDScript = preload("res://test/helpers/recording_engine.gd")
var engine: ScenarioEngine
var health: Health
var player: Player


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	health = add_child_autofree(Health.new())
	health.shields = 10
	player = make_player()
	player.health = health


func _fortify(upgraded: bool, bonuses: Array[int]) -> void:
	var path: String = "res://Source/Content/Tiles/TileResources/fortress_protocol%s.tres" % ("_plus" if upgraded else "")
	var resource: TileResource = load(path)
	var tile: Tile = autofree(Tile.new())
	tile.tile_resource = resource
	var step: EffectData
	for data: EffectData in resource.effect_chain.effects:
		if data.multiply_shields:
			step = data
	assert_not_null(step)
	var context: EffectContext = EffectContext.new()
	context.effect_source = tile
	context.targets = [player]
	context.running_amount = 5 if upgraded else 0
	GainShieldsHandler.new().apply(step, context, engine)
	var event: ShieldEvent = engine.get("injected")[0] as ShieldEvent
	for bonus: int in bonuses:
		AmplifierModifier.new(tile, bonus).on_before_event(event, engine)
	await event.resolve(engine)


func test_fortress_doubles_normally_and_quadruples_when_amplified() -> void:
	await _fortify(false, [])
	assert_eq(health.shields, 20)
	health.shields = 10
	engine.get("injected").clear()
	await _fortify(false, [1])
	assert_eq(health.shields, 40)


func test_amplifiers_stack_on_the_multiplier_and_keep_the_upgrade_bonus_separate() -> void:
	await _fortify(true, [1, 1])
	assert_eq(health.shields, 65, "2x becomes 6x with total Amplify +2, then the upgrade adds 5")


func test_flat_shield_gains_keep_flat_amplification() -> void:
	var event: ShieldEvent = ShieldEvent.new()
	event.amount = 5
	event.targets = [player]
	event.amplify(1)
	await event.resolve(engine)
	assert_eq(health.shields, 16)


func test_multiplier_grants_snapshot_each_targets_shields() -> void:
	var other: Player = make_player()
	other.health = add_child_autofree(Health.new())
	other.health.shields = 5
	var context: EffectContext = EffectContext.new()
	context.targets = [player, other]
	var data: EffectData = EffectData.new()
	data.multiply_shields = true
	data.multiplier = 2.0
	GainShieldsHandler.new().apply(data, context, engine)
	for event: EffectEvent in engine.get("injected"):
		event.amplify(1)
		await event.resolve(engine)
	assert_eq(health.shields, 40)
	assert_eq(other.health.shields, 20)


func test_amplify_grows_a_marked_multiply_step_instead_of_the_product() -> void:
	var amounts: Array[int] = []
	for marked: bool in [false, true]:
		var context: EffectContext = EffectContext.new()
		context.targets = [player]
		context.running_amount = 4
		var step: EffectData = EffectData.new()
		step.multiplier = 3.0
		step.amplify_multiplier = marked
		MultiplyAmountHandler.new().apply(step, context, engine)
		DealDamageHandler.new().apply(EffectData.new(), context, engine)
		var event: EffectEvent = engine.get("injected").pop_back()
		event.amplify(2)
		amounts.append(event.amount)
	assert_eq(amounts, [14, 20], "4x3 then +2 flat; marked, 4x(3+2)")
