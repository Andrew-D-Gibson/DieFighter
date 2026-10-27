extends "res://test/helpers/die_fighter_test.gd"
## SIPHON_ENGINE_CHARGE: an enemy pulling charge out of the player's drive in
## pulses (the Engine Siphon intent).


func _siphon(amount: int, actor: Node = null) -> SiphonEngineChargeEvent:
	var event := SiphonEngineChargeEvent.new()
	event.amount = amount
	event.actor = actor
	await event.resolve(null)
	return event


func test_takes_the_amount_from_the_drive() -> void:
	Globals.player = make_player(5, 10)
	var event := await _siphon(4)
	assert_eq(Globals.player.engine_charge, 6)
	assert_eq(event.taken, 4)


func test_never_takes_more_than_the_drive_holds() -> void:
	Globals.player = make_player(5, 2)
	var event := await _siphon(5)
	assert_eq(Globals.player.engine_charge, 0)
	assert_eq(event.taken, 2)


func test_the_gauge_drops_before_the_drain_finishes() -> void:
	# The first pulse lands at once, so the player sees the loss before any
	# motes leave the gauge.
	Globals.player = make_player(5, 10)
	var event := SiphonEngineChargeEvent.new()
	event.amount = 3
	event.resolve(null)
	assert_eq(Globals.player.engine_charge, 9)
	await wait_seconds(1.5)
	assert_eq(Globals.player.engine_charge, 7)


func test_an_enemy_drain_arms_retaliation_once() -> void:
	Globals.player = make_player(5, 10)
	var enemy: Enemy = autofree(Enemy.new())
	watch_signals(Events)
	await _siphon(6, enemy)
	assert_signal_emit_count(Events, "engine_charge_drained", 1)


func test_a_drain_is_not_amplified() -> void:
	assert_false(SiphonEngineChargeEvent.new().is_amplifiable())


func test_the_engine_siphon_intent_uses_it() -> void:
	var action: EnemyActionResource = load(
		"res://Source/Content/Enemies/EnemyActions/EnemyActionResources/siphon_engine.tres")
	var found: bool = false
	for effect: EffectData in action.effect_chain.effects:
		found = found or (effect.category == EffectEnums.Category.ATTRIBUTE_CHANGE
				and effect.subtype == EffectEnums.AttributeChangeSubtype.SIPHON_ENGINE_CHARGE)
	assert_true(found)
