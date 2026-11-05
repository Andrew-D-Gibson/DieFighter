extends "res://test/helpers/die_fighter_test.gd"
## A Continue taken partway through a scenario rebuilds the hand from the
## save. Anything else already standing by then (a restored shop's die on
## its shelf, an unclaimed salvage die) belongs to its offer, not the hand.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var player: Player


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	player.num_of_dice = 1
	var state_manager: GameStateManager = autofree(GameStateManager.new())
	state_manager._restore = {"dice": [{"value": 4}]}
	Globals.state_manager = state_manager


func test_rebuilding_the_hand_leaves_dice_on_offer_alone() -> void:
	var on_offer: Dice = DICE_SCENE.instantiate()
	on_offer.put_on_offer()
	add_child_autofree(on_offer)

	await player._restore_saved_hand()

	assert_true(is_instance_valid(on_offer) and not on_offer.is_queued_for_deletion(),
		"the shop's die stays on its shelf")
	assert_eq(player.dice_manager.queue.size(), 1)
	assert_eq(player.dice_manager.queue[0].value, 4)
