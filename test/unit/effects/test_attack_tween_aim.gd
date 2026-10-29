extends "res://test/helpers/die_fighter_test.gd"
## Where an attack tween's die strikes: a ship's hull for a ship, and the hull
## readout on the health bar for the player, wherever the ship's cockpit has
## mounted the bar.

const PLAYER_SCENE: PackedScene = preload("res://Source/Systems/Game/Player/player.tscn")
const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var _saved_speed: float


func before_each() -> void:
	super()
	# The flight's length doesn't matter here, only where it ends.
	_saved_speed = Globals.animation_speed
	Globals.animation_speed = 25.0


func after_each() -> void:
	Globals.animation_speed = _saved_speed
	super()


func _fire_at(target: Node2D, shooter: Node2D) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.value = 3
	shooter.add_child(die)
	die.global_position = Vector2(10, 10)
	var event: AttackTweenEvent = AttackTweenEvent.new()
	event.actor = shooter
	event.activator_die = die
	event.targets = [target]
	await event.resolve(null)
	return die


func test_a_shot_at_the_player_strikes_the_hull_readout() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	# A cockpit that mounts the gauge somewhere unusual (HudSlots).
	var bar: PlayerHealthBar = player.get_node("PlayerHealthBar")
	bar.global_position = Vector2(240, 150)
	var shooter: Node2D = add_child_autofree(Node2D.new())

	var die: Dice = await _fire_at(player, shooter)

	assert_almost_eq(die.global_position, bar.get_hull_anchor(), Vector2.ONE * 0.5)
	assert_ne(bar.get_hull_anchor(), player.global_position,
		"the bar, not the player node, which nothing draws")


func test_the_hull_anchor_follows_the_bar() -> void:
	var player: Player = add_child_autofree(PLAYER_SCENE.instantiate())
	var bar: PlayerHealthBar = player.get_node("PlayerHealthBar")
	bar.global_position = Vector2(40, 60)
	var first: Vector2 = player.get_hull_anchor()
	bar.global_position = Vector2(140, 90)

	assert_almost_eq(player.get_hull_anchor() - first, Vector2(100, 30), Vector2.ONE * 0.01)


func test_a_shot_at_a_ship_still_strikes_the_ship() -> void:
	var ship: Node2D = add_child_autofree(Node2D.new())
	ship.global_position = Vector2(120, 30)
	var shooter: Node2D = add_child_autofree(Node2D.new())

	var die: Dice = await _fire_at(ship, shooter)

	assert_almost_eq(die.global_position, Vector2(120, 30), Vector2.ONE * 0.5)
