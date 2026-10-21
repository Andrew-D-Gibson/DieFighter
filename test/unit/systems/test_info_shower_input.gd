extends "res://test/helpers/die_fighter_test.gd"
## Escape while the info shower is open closes it, and goes no further: the
## pause menu, opened by the InputManager autoload on the same action, must
## not open behind it.

const INFO_SHOWER: PackedScene = preload("res://Source/Systems/UI/InfoShower/info_shower.tscn")


## Stands in for InputManager: a node ahead of the game scene in the tree,
## where the autoloads live, so it hears unhandled input after the scene does.
class UnhandledInputProbe:
	extends Node

	var heard_pause: bool = false

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("PauseMenu"):
			heard_pause = true


var info_shower: Control
var probe: UnhandledInputProbe


func before_each() -> void:
	super()
	probe = UnhandledInputProbe.new()
	get_tree().root.add_child(probe)
	get_tree().root.move_child(probe, 0)
	autofree(probe)
	info_shower = add_child_autofree(INFO_SHOWER.instantiate())


static func _escape() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	return event


func test_escape_closes_an_open_info_shower() -> void:
	watch_signals(Events)
	info_shower.show()
	get_tree().root.push_input(_escape())
	assert_false(info_shower.visible)
	assert_signal_emitted(Events, "info_graphic_closed")


func test_escape_on_an_open_info_shower_doesnt_reach_the_pause_menu() -> void:
	info_shower.show()
	get_tree().root.push_input(_escape())
	assert_false(probe.heard_pause)


func test_escape_with_the_info_shower_shut_still_pauses() -> void:
	watch_signals(Events)
	get_tree().root.push_input(_escape())
	assert_true(probe.heard_pause)
	assert_signal_not_emitted(Events, "info_graphic_closed")
