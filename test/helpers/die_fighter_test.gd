extends GutTest
## Base class for DieFighter tests. Keeps Globals clean between tests.
##
## Subclasses that override before_each()/after_each() must call super().

const Effects := preload("res://test/helpers/effects.gd")
const FakeDie := preload("res://test/helpers/fake_die.gd")
const GlobalsSandbox := preload("res://test/helpers/globals_sandbox.gd")

var _globals: GlobalsSandbox


func before_each() -> void:
	_globals = GlobalsSandbox.new()


func after_each() -> void:
	_globals.restore()


## A bare Player whose charge maths works. It is not in the tree, so none of
## its @onready children exist: use it for engine charge, not dice or health.
func make_player(num_of_dice: int = 5, charge: int = 0) -> Player:
	var player: Player = autofree(Player.new())
	player.num_of_dice = num_of_dice
	player.engine_charge = charge
	return player
