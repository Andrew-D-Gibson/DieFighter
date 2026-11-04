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
