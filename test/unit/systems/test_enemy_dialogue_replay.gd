extends "res://test/helpers/die_fighter_test.gd"
## EnemyDialogueManager remembers its last line so the targeting computer's
## comms button can have the ship say it again.

const _SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyDialogueManager/enemy_dialogue_manager.tscn")


func _manager() -> EnemyDialogueManager:
	var manager: EnemyDialogueManager = _SCENE.instantiate()
	add_child_autofree(manager)
	# Lines from an earlier test mustn't make this one wait its turn.
	EnemyDialogueManager.time_last_dialogue_was_shown = 0
	return manager


func test_a_ship_that_has_said_nothing_has_nothing_to_replay() -> void:
	assert_false(_manager().has_line_to_replay())


func test_a_line_can_be_replayed_and_is_shown_again() -> void:
	var manager := _manager()
	manager.show_dialogue("Our kill. Back off!")
	manager.hide()
	watch_signals(manager)
	manager.replay_last_line()
	assert_true(manager.has_line_to_replay())
	assert_signal_emitted(manager, "line_shown")
	assert_true(manager.visible)
	assert_eq(manager.get_node("%RichTextLabel").text, "Our kill. Back off!")


func test_clearing_the_box_keeps_the_last_real_line() -> void:
	var manager := _manager()
	manager.show_dialogue("Hold fire!")
	manager.show_dialogue("")
	assert_true(manager.has_line_to_replay())


func test_a_ship_left_behind_in_a_jump_has_nothing_more_to_say() -> void:
	var manager := _manager()
	manager.show_dialogue("Hold fire!")
	manager._on_jump()
	assert_false(manager.has_line_to_replay())
