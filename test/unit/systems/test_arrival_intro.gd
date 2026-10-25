extends "res://test/helpers/die_fighter_test.gd"
## ArrivalIntro: the beats between arriving and the ships flying in play one
## at a time, in order, and nothing can hold the ships forever.

var intro: ArrivalIntro
var played: Array[String] = []


func before_each() -> void:
	super()
	played.clear()
	intro = ArrivalIntro.new()


func _beat(beat_name: String, frames: int = 2) -> Callable:
	return func() -> void:
		played.append(beat_name + " starts")
		for i: int in range(frames):
			await get_tree().process_frame
		played.append(beat_name + " ends")


func test_beats_play_one_at_a_time_in_order() -> void:
	Events.start_scenario.emit()
	# Added in the opposite order: the boss band still goes last.
	intro.add(ArrivalIntro.Beat.BOSS, _beat("boss"))
	intro.add(ArrivalIntro.Beat.REGION_RULE, _beat("rule"))
	await intro.wait()
	assert_eq(played, ["rule starts", "rule ends", "boss starts", "boss ends"] as Array[String])


func test_an_arrival_with_no_beats_lets_the_ships_straight_in() -> void:
	Events.start_scenario.emit()
	await intro.wait()
	assert_false(intro._playing)


func test_waiting_with_no_arrival_under_way_returns_at_once() -> void:
	await intro.wait()
	pass_test("returned")


func test_beats_are_gathered_only_while_the_arrival_is_answered() -> void:
	assert_false(intro.is_collecting())
	Events.start_scenario.emit()
	assert_true(intro.is_collecting())
	await intro.wait()
	assert_false(intro.is_collecting())


func test_a_beat_that_never_ends_is_given_up_on() -> void:
	intro.max_beat_seconds = 0.2
	var never: Callable = func() -> void:
		await Events.player_turn_over
	Events.start_scenario.emit()
	intro.add(ArrivalIntro.Beat.REGION_RULE, never)
	intro.add(ArrivalIntro.Beat.BOSS, _beat("boss"))
	await intro.wait()
	assert_eq(played, ["boss starts", "boss ends"] as Array[String])


func test_a_jump_lets_the_ships_go_and_drops_the_rest() -> void:
	Events.start_scenario.emit()
	intro.add(ArrivalIntro.Beat.REGION_RULE, _beat("rule", 30))
	intro.add(ArrivalIntro.Beat.BOSS, _beat("boss"))
	var waiting: Callable = func() -> void:
		await intro.wait()
		played.append("ships")
	waiting.call()
	for i: int in range(4):
		await get_tree().process_frame
	Events.jump.emit()
	await get_tree().process_frame
	assert_has(played, "ships")
	assert_does_not_have(played, "boss starts")
