extends "res://test/helpers/die_fighter_test.gd"
## The Reckoning's rules that end a run (RECKONING_ENDINGS.md §1, §5): which
## ending each way out of the fight comes to, and the escape goal holding
## still while dice leave.

const T := ReckoningRules.Trigger
const K := ReckoningEnding.Kind

var no_one: Array[String] = []
var nothing_missed: Array[Dictionary] = []


func _kind(trigger: ReckoningRules.Trigger, saved_out: Array[String] = no_one, bank_full: bool = false) -> int:
	return ReckoningRules.resolve(trigger, bank_full, saved_out, no_one, no_one, nothing_missed).kind


func test_each_way_out_comes_to_its_ending() -> void:
	var one_out: Array[String] = ["hauler"]
	assert_eq(_kind(T.JUMPED), K.ALONE, "jumped with nobody out")
	assert_eq(_kind(T.JUMPED, one_out), K.CONVOY, "jumped after an ally got out")
	assert_eq(_kind(T.LAST_DIE_TO_ALLY, one_out), K.LAST_DIE)
	assert_eq(_kind(T.LAST_DIE_TO_ECHO), K.FELL_IN)
	assert_eq(_kind(T.LAST_DIE_TO_ECHO, no_one, true), K.FELL_IN, "an echo's theft is never spared")
	assert_eq(_kind(T.HULL_ZERO), K.FELL_IN)
	assert_eq(_kind(T.SELF_DESTROYED), K.BECOME_FATE)
	# The last die leaving with an ally on a full bank doesn't consume the
	# player: the arrow is lit and the fight goes on.
	assert_false(ReckoningRules.ends_fight(T.LAST_DIE_TO_ALLY, true))
	assert_null(ReckoningRules.resolve(T.LAST_DIE_TO_ALLY, true, one_out, no_one, no_one, nothing_missed))

	# Only a Convoy that left nobody behind, in the fight or before it, is
	# perfect.
	var out: Array[String] = ["hauler", "tug"]
	var someone: Array[String] = ["picket"]
	var a_miss: Array[Dictionary] = [{"enemy": "civilian_transport", "reason": ReckoningEnding.MISSED_KILLED}]
	assert_true(ReckoningRules.resolve(T.JUMPED, false, out, no_one, no_one, nothing_missed).perfect)
	assert_false(ReckoningRules.resolve(T.JUMPED, false, out, someone, no_one, nothing_missed).perfect, "left behind")
	assert_false(ReckoningRules.resolve(T.JUMPED, false, out, no_one, someone, nothing_missed).perfect, "lost")
	assert_false(ReckoningRules.resolve(T.JUMPED, false, out, no_one, no_one, a_miss).perfect, "missed in the run")
	assert_false(ReckoningRules.resolve(T.LAST_DIE_TO_ALLY, false, out, no_one, no_one, nothing_missed).perfect,
		"only the Convoy is ever perfect")


## The goal is the drive as it stands when the fight begins, and handing dice
## away mustn't lower it; once the fight is over the drive follows the dice
## again.
func test_the_escape_goal_is_fixed_when_the_fight_begins() -> void:
	var player: Player = make_player(3)
	var drive: int = player.max_engine_charge
	var goal: int = ReckoningRules.escape_goal(drive, 3.0)
	assert_eq(goal, drive * 3)
	player.freeze_engine_max(goal)
	player.num_of_dice = 1
	assert_eq(player.max_engine_charge, goal)
	player.release_engine_max()
	assert_eq(player.max_engine_charge, Player.engine_max_for(1))
