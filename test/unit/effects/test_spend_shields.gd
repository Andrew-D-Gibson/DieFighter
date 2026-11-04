extends "res://test/helpers/die_fighter_test.gd"
## SPEND_SHIELDS: the player paying for a payoff with shields, e.g. Discharge
## Plate. A price, so it must not read as the shields being hit.

const RecordingEngine := preload("res://test/helpers/recording_engine.gd")

var engine: RecordingEngine
var health: Health


func before_each() -> void:
	super()
	engine = autofree(RecordingEngine.new())
	health = add_child_autofree(Health.new())
	health.shields = 10
	var player := make_player()
	player.health = health
	Globals.player = player
	watch_signals(health)


func _spend(amount: int) -> void:
	var event := SpendShieldsEvent.new()
	event.amount = amount
	event.resolve(engine)


func test_spending_is_not_a_hit() -> void:
	_spend(10)
	assert_eq(health.shields, 0)
	assert_signal_not_emitted(health, "shields_damaged")
	assert_signal_not_emitted(health, "shields_broken")


func test_spending_more_than_the_player_has_refuses() -> void:
	_spend(11)
	assert_eq(health.shields, 10)


func test_a_price_is_not_amplified() -> void:
	assert_false(SpendShieldsEvent.new().is_amplifiable())


func test_handler_falls_back_to_the_running_amount() -> void:
	var data := Effects.data(EffectEnums.Category.ATTRIBUTE_CHANGE, EffectEnums.AttributeChangeSubtype.SPEND_SHIELDS)
	var context := EffectContext.new()
	context.running_amount = 4
	await EffectRegistry.get_handler(data.category, data.subtype).apply(data, context, engine)
	assert_eq(engine.injected.size(), 1)
	assert_eq((engine.injected[0] as SpendShieldsEvent).amount, 4)


func test_discharge_plate_authored_with_dbz_beam_flourish() -> void:
	for path: String in [
		"res://Source/Content/Tiles/TileResources/discharge_plate.tres",
		"res://Source/Content/Tiles/TileResources/discharge_plate_plus.tres",
	]:
		var tile_res: TileResource = load(path)
		assert_not_null(tile_res, path)
		var step: EffectData = tile_res.effect_chain.effects[6]
		assert_eq(step.category, EffectEnums.Category.AUDIO_VISUAL)
		assert_eq(step.subtype, EffectEnums.AudioVisualSubtype.LASER)
		assert_eq(step.juice_flags, JuiceEvent.Flag.BIG)
		assert_true(step.color.is_equal_approx(Color(0.2627, 0.651, 0.9882, 1)))


func test_discharge_beam_stages_and_impact_timing() -> void:
	var host: Node2D = add_child_autofree(Node2D.new())
	var target: Node2D = add_child_autofree(Node2D.new())
	target.global_position = Vector2(200, 50)
	var impact_sec: float = Juice.discharge_beam(
		host,
		Vector2(28, 92),
		Vector2(48, 72),
		Vector2(140, 110),
		target.global_position,
		Globals.blue,
		0.0,
		target
	)
	assert_gt(impact_sec, 0.5)
	var beam: JuiceDischargeBeam = JuiceDischargeBeam.new()
	beam.host_node = host
	beam.shield_from = Vector2(28, 92)
	beam.hull_from = Vector2(48, 72)
	beam.from = Vector2(140, 110)
	beam.to = Vector2(200, 50)
	add_child_autofree(beam)
	beam._process(0.2)
	assert_false(beam._impact_triggered)
	beam._process(0.4)
	assert_false(beam._impact_triggered)
	beam._process(0.2)
	assert_true(beam._impact_triggered)
