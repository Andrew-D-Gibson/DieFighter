extends "res://test/helpers/die_fighter_test.gd"
## Rewards paid per fight rather than per kill: when a faction's bounty is the
## player's to take, and the chance an offer carries a money option.

const Ships := preload("res://test/helpers/ships.gd")
const Faction := ScenarioManager.Faction


func _ship() -> Enemy:
	var made: Enemy = Ships.ship(Faction.PIRATE)
	autofree(made.health)
	return autofree(made)


# ── Who earns the bounty ───────────────────────────────────────────────────────

func test_destroying_the_last_ship_earns_the_bounty() -> void:
	var ship := _ship()
	ship.health.change_health(-ship.health.max_health)
	assert_true(ScenarioManager.earns_faction_bounty(ship))


func test_a_last_ship_that_escapes_takes_the_bounty_with_it() -> void:
	# Flee and Escape With Dice leave without dying.
	assert_false(ScenarioManager.earns_faction_bounty(_ship()))


func test_a_last_ship_finished_by_another_ship_pays_nothing() -> void:
	var ship := _ship()
	ship.last_damaged_by = _ship()
	ship.health.change_health(-ship.health.max_health)
	assert_false(ScenarioManager.earns_faction_bounty(ship))


# ── The money option ───────────────────────────────────────────────────────────

func _money_offer(probability: float) -> RewardResource:
	var reward := RewardResource.new()
	reward.max_money_pickup = 10
	reward.money_pickup_probability = probability
	return reward


func test_a_certain_money_option_always_shows_and_draws_nothing() -> void:
	RNGManager.seed_scenario(5)
	var expected: float = RNGManager.randf(RNGManager.Bucket.REWARDS)
	RNGManager.seed_scenario(5)
	assert_true(Reward.rolls_money_pickup(_money_offer(1.0)))
	assert_eq(RNGManager.randf(RNGManager.Bucket.REWARDS), expected,
		"offers authored before the chance existed keep their seeded rolls")


func test_an_impossible_money_option_never_shows() -> void:
	RNGManager.seed_scenario(5)
	for i: int in range(50):
		assert_false(Reward.rolls_money_pickup(_money_offer(0.0)))


func test_a_partial_chance_sometimes_shows() -> void:
	RNGManager.seed_scenario(5)
	var shown: int = 0
	for i: int in range(200):
		if Reward.rolls_money_pickup(_money_offer(0.5)):
			shown += 1
	assert_between(shown, 60, 140)
