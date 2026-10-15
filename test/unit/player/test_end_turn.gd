extends "res://test/helpers/die_fighter_test.gd"
## When the End Turn button may come up: only once every die the player has
## put down has actually been played, not just once the hand is empty.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")

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
