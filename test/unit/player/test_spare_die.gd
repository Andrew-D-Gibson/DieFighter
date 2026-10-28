extends "res://test/helpers/die_fighter_test.gd"
## The spare die: whenever it's the player's move and they have nothing to
## play, they're given one. Real if the Fleet owns a die nobody is holding,
## otherwise a hologram.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Source/Content/Enemies/enemy.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")
const INTERCEPTOR: EnemyResource = preload("res://Source/Content/Enemies/EnemyResources/interceptor.tres")

var player: Player


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 2


func _ship() -> Enemy:
	var ship: Enemy = ENEMY_SCENE.instantiate()
	ship.enemy_resource = INTERCEPTOR
	var state: ScenarioShipState = ScenarioShipState.new()
	state.faction = ScenarioManager.Faction.PIRATE
	ship.scenario_state = state
	return add_child_autofree(ship)


## A die under the player node, where every die in the game lives.
func _die(face: int = 3) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = face
	player.add_child(die)
	return die


func test_a_hand_with_a_die_gets_no_spare() -> void:
	player.dice_manager.add(_die())
	await player._ensure_a_die_to_play()
	assert_eq(player.dice_manager.queue.size(), 1)


func test_a_die_a_tile_is_holding_counts_as_one_to_play() -> void:
	# Any queue that isn't a ship's: it hands the die back.
	var tile_queue: DiceQueue = add_child_autofree(DiceQueue.new())
	tile_queue.add(_die())
	await player._ensure_a_die_to_play()
	assert_eq(player.dice_manager.queue.size(), 0)


func test_with_every_die_in_a_ships_hands_a_hologram_stands_in() -> void:
	var ship: Enemy = _ship()
	ship.dice_manager.add(_die(2))
	ship.dice_manager.add(_die(5))

	await player._ensure_a_die_to_play()

	assert_eq(player.dice_manager.queue.size(), 1)
	assert_true(player.dice_manager.queue[0].holographic, "the Fleet owns no die nobody is holding")
	assert_eq(player.dice_owned(), 3, "both real dice are still the player's, plus the hologram")


func test_a_die_the_fleet_owns_but_nobody_holds_turns_up_for_real() -> void:
	# A Cutpurse fled with the rest; the count never drops below one.
	player.num_of_dice = 1
	await player._ensure_a_die_to_play()

	assert_eq(player.dice_manager.queue.size(), 1)
	assert_false(player.dice_manager.queue[0].holographic)


func test_a_die_on_its_way_to_a_ship_isnt_one_to_play() -> void:
	# A die fired off a tile still points at the tile's queue until it lands.
	player.num_of_dice = 1
	var tile_queue: DiceQueue = add_child_autofree(DiceQueue.new())
	var fired: Dice = _die()
	tile_queue.add(fired)
	tile_queue.remove(fired)

	await player._ensure_a_die_to_play()

	assert_eq(player.dice_manager.queue.size(), 1)
	assert_true(player.dice_manager.queue[0].holographic, "the fired die is still the player's")


func test_no_spare_once_the_player_is_leaving() -> void:
	player.commit_to_jump(null)
	await player._ensure_a_die_to_play()
	assert_eq(player.dice_manager.queue.size(), 0, "arrival deals the hand")


# ── A fight the player started with their last die ────────────────────────────

## The player drops their last die on a tile: the hand is empty by their own
## hand, and the die is on its way to a ship.
func _spend_last_die() -> void:
	var die: Dice = _die()
	player.dice_manager.add(die)
	player.dice_manager.remove(die)
	var tile_queue: DiceQueue = add_child_autofree(DiceQueue.new())
	tile_queue.add(die)
	Events.die_placed_on_tile.emit(die, null)
	tile_queue.remove(die)


func test_starting_a_fight_with_the_last_die_deals_no_spare() -> void:
	_spend_last_die()
	await player._ensure_a_die_for_first_turn()
	assert_eq(player.dice_manager.queue.size(), 0, "the player spent their own turn")


func test_the_next_turn_still_rescues_an_empty_hand() -> void:
	_spend_last_die()
	await player._ensure_a_die_to_play()
	assert_eq(player.dice_manager.queue.size(), 1)


func test_a_die_coming_home_clears_it() -> void:
	_spend_last_die()
	var back: Dice = _die()
	player.dice_manager.add(back)
	player.dice_manager.remove(back)
	back.queue_free()
	await player._ensure_a_die_for_first_turn()
	assert_eq(player.dice_manager.queue.size(), 1, "ships took the hand after it was refilled")


func test_a_fight_starting_on_a_hand_ships_emptied_still_deals_one() -> void:
	var ship: Enemy = _ship()
	ship.dice_manager.add(_die(4))
	await player._ensure_a_die_for_first_turn()
	assert_eq(player.dice_manager.queue.size(), 1)
