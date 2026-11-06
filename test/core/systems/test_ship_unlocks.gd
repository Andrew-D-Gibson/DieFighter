extends "res://test/helpers/die_fighter_test.gd"
## ShipUnlocks: a ship earned by Fate's Die is earned only by a die bearing
## its face as often as it asks. Read from each ship's own numbers, so it
## holds however they're tuned.


func test_a_die_earns_a_ship_only_with_enough_of_its_face() -> void:
	var checked: int = 0
	for ship: ShipResource in ShipCatalog.all():
		if ship.unlock_face == FateDie.Face.BLANK:
			assert_false(ShipUnlocks.die_earns(ship, _die_with(FateDie.Face.MERCY, FateDie.FACE_COUNT)),
				"%s isn't earned by a face" % ship.id)
			continue
		checked += 1
		assert_true(ShipUnlocks.die_earns(ship, _die_with(ship.unlock_face, ship.unlock_face_count)),
			"%s: enough faces earn it" % ship.id)
		assert_false(ShipUnlocks.die_earns(ship, _die_with(ship.unlock_face, ship.unlock_face_count - 1)),
			"%s: one face short doesn't" % ship.id)
	if checked == 0:
		pass_test("no ship is earned by a face")


## A die with [param count] of [param face] carved, the rest blank.
func _die_with(face: FateDie.Face, count: int) -> FateDie:
	var die: FateDie = FateDie.new()
	for i: int in count:
		die.carve(face)
	return die
