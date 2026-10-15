extends "res://test/helpers/die_fighter_test.gd"
## STEAL_MONEY: a ship taking credits off the player, e.g. the Tollkeeper's toll.


func _steal(amount: int) -> StealMoneyEvent:
	var event := StealMoneyEvent.new()
	event.amount = amount
	await event.resolve(null)
	return event


func test_takes_the_amount_from_the_balance() -> void:
	Globals.player = make_player()
	Globals.player.money = 30
	var event := await _steal(12)
	assert_eq(Globals.player.money, 18)
	assert_eq(event.taken, 12)


func test_never_takes_more_than_the_player_has() -> void:
	Globals.player = make_player()
	Globals.player.money = 5
	var event := await _steal(12)
	assert_eq(Globals.player.money, 0)
	assert_eq(event.taken, 5)


func test_a_broke_player_loses_nothing() -> void:
	Globals.player = make_player()
	var event := await _steal(12)
	assert_eq(Globals.player.money, 0)
	assert_eq(event.taken, 0)


func test_a_toll_is_not_amplified() -> void:
	assert_false(StealMoneyEvent.new().is_amplifiable())
