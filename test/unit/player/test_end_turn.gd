extends "res://test/helpers/die_fighter_test.gd"
## When the End Turn button may come up: only once every die the player has
## put down has actually been played, not just once the hand is empty, and
## only while it's the player's turn to end.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var player: Player
var engine: ScenarioEngine


func before_each() -> void:
	super()
	player = add_child_autofree(PLAYER_SCENE.instantiate())
	engine = autofree(ScenarioEngine.new())
	var manager: ScenarioManager = autofree(ScenarioManager.new())
	manager.engine = engine
	Globals.scenario_manager = manager


func _end_turn_button() -> Node:
	return player.get_node("%EndTurnButton")


func test_an_empty_hand_with_nothing_left_to_fire_can_end_the_turn() -> void:
	Events.tile_activation_complete.emit()
	assert_false(_end_turn_button().disabled)


func test_a_die_still_queued_on_a_tile_holds_the_turn_open() -> void:
	# A Bump waiting behind a Dice Cannon: the hand is empty, but that die
	# hasn't been played yet.
	engine.event_queue.append(TileActivationEvent.new())
	Events.tile_activation_complete.emit()
	assert_true(_end_turn_button().disabled)

	engine.event_queue.clear()
	Events.tile_activation_complete.emit()
	assert_false(_end_turn_button().disabled)


func test_committing_to_a_jump_keeps_end_turn_off() -> void:
	# The die that fired the jump finishes activating while the map is still
	# panning, with the hand empty.
	Events.tile_activation_complete.emit()
	player.commit_to_jump(null)
	assert_true(_end_turn_button().disabled)

	Events.tile_activation_complete.emit()
	assert_true(_end_turn_button().disabled, "an enemy turn started now would play out mid-jump")
	assert_false(player.can_end_turn())


func test_committing_to_a_jump_locks_the_hand() -> void:
	var die: Dice = DICE_SCENE.instantiate()
	player.add_child(die)
	player.dice_manager.add(die)

	player.commit_to_jump(null)

	assert_false(die.draggable.dragging_allowed, "nothing more is played once the player is leaving")
	assert_true(die.transit_locked, "so arrival knows to unlock it")


func test_end_turn_stays_off_after_the_press() -> void:
	Events.tile_activation_complete.emit()
	player.end_turn()

	# A tile that finishes activating after the press.
	Events.tile_activation_complete.emit()
	assert_true(_end_turn_button().disabled, "a second press would start a second enemy turn")
