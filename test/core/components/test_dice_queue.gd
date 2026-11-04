extends "res://test/helpers/die_fighter_test.gd"
## DiceQueue: ownership moves with the die, holographic dice burn out, and
## has_value() answers "is anyone holding a <n>?".

const DICE_SCENE: PackedScene = preload("res://Source/Systems/Game/Dice/dice.tscn")

var queue: DiceQueue


func before_each() -> void:
	super()
	queue = autofree(DiceQueue.new())


## A real die, kept out of the tree so it doesn't roll itself in _ready().
func _die(face: int, holographic: bool = false) -> Dice:
	var die: Dice = DICE_SCENE.instantiate()
	die.holographic = holographic
	die.value = face
	return autofree(die)


func test_add_takes_ownership() -> void:
	watch_signals(queue)
	var die := _die(3)
	queue.add(die)
	assert_eq(queue.queue, [die] as Array[Dice])
	assert_same(die.host_queue, queue)
	assert_signal_emitted(queue, "die_added")


func test_adding_the_same_die_twice_does_not_duplicate_it() -> void:
	var die := _die(3)
	queue.add(die)
	queue.add(die)
	assert_eq(queue.queue.size(), 1)


func test_add_moves_a_die_away_from_its_previous_owner() -> void:
	var previous: DiceQueue = autofree(DiceQueue.new())
	var die := _die(3)
	previous.add(die)
	queue.add(die)
	assert_true(previous.queue.is_empty())
	assert_same(die.host_queue, queue)


func test_add_preserves_the_face_by_default() -> void:
	var die := _die(5)
	queue.add(die)
	assert_eq(die.value, 5)


func test_holographic_dice_are_destroyed_on_return() -> void:
	var die := _die(3, true)
	queue.add(die)
	assert_true(queue.queue.is_empty())
	assert_true(die.is_queued_for_deletion())


func test_holographic_dice_can_be_kept_when_asked() -> void:
	var die := _die(3, true)
	queue.add(die, true, false)
	assert_eq(queue.queue.size(), 1)


func test_remove_only_signals_for_dice_it_held() -> void:
	watch_signals(queue)
	queue.remove(_die(2))
	assert_signal_not_emitted(queue, "die_removed")

	var die := _die(2)
	queue.add(die)
	queue.remove(die)
	assert_signal_emit_count(queue, "die_removed", 1)


func test_has_value() -> void:
	queue.add(_die(2))
	queue.add(_die(6))
	assert_true(queue.has_value(6))
	assert_false(queue.has_value(4))
