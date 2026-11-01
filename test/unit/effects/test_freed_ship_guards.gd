extends "res://test/helpers/die_fighter_test.gd"
## A ship destroyed while an event about it waits in the queue is a freed
## object by the time the event resolves or is logged. GDScript refuses to
## pass one to a Node parameter at all, so these helpers take it untyped and
## check it themselves. Both used to throw "previously freed" in the AutoPilot.


func _freed_node() -> Node:
	var node: Node = Node.new()
	node.free()
	return node


func test_a_freed_subject_is_no_longer_in_the_fight() -> void:
	assert_false(TileEventTriggeredEvent.still_in_fight(_freed_node()))


func test_a_missing_subject_is_no_longer_in_the_fight() -> void:
	assert_false(TileEventTriggeredEvent.still_in_fight(null))


func test_a_freed_target_has_no_vitals() -> void:
	assert_eq(DebugLogFormat.vitals(_freed_node()), "")


func test_logging_a_hit_on_a_freed_target_names_no_one() -> void:
	# Aimed while the ship was alive, freed before the line is written.
	var ship: Node = Node.new()
	var event: DamageEvent = DamageEvent.new()
	event.amount = 3
	event.targets.append(ship)
	ship.free()
	assert_string_contains(DebugLogFormat.event_line(event), "DAMAGE 3")
